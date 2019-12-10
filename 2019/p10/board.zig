const std = @import("std");
const assert = std.debug.assert;

const TargetInfo = struct {
    angle: i32,
    x: i32,
    y: i32,
    dist: usize,
    shot: bool,
};
fn cmpByAngle(l: TargetInfo, r: TargetInfo) bool {
    if (l.angle < r.angle) return true;
    if (l.angle > r.angle) return false;
    return l.dist < r.dist;
}

pub const Board = struct {
    mx: usize,
    my: usize,
    data: [50][50]usize,

    pub fn init() Board {
        var self = Board{
            .mx = 0,
            .my = 0,
            .data = undefined,
        };
        return self;
    }

    pub fn deinit(self: Board) void {}

    pub fn add_line(self: *Board, str: []const u8) void {
        var j: usize = 0;
        while (j < str.len) : (j += 1) {
            var c: usize = 0;
            if (str[j] == '#') c = 1;
            self.data[self.my][j] = c;
        }
        if (self.mx < j) {
            self.mx = j;
        }
        self.my += 1;
    }

    fn gcd(a: usize, b: usize) usize {
        var la = a;
        var lb = b;
        while (lb != 0) {
            const t = lb;
            lb = la % lb;
            la = t;
        }
        return la;
    }

    pub fn show(self: Board) void {
        var sy: usize = 0;
        std.debug.warn("BOARD {}x{}\n", self.my, self.mx);
        while (sy < self.my) : (sy += 1) {
            var sx: usize = 0;
            std.debug.warn("[");
            while (sx < self.mx) : (sx += 1) {
                std.debug.warn("{}", self.data[sy][sx]);
            }
            std.debug.warn("]\n");
        }
    }

    pub fn find_best_position(self: *Board) usize {
        var mc: usize = 0;
        var mx: usize = 0;
        var my: usize = 0;

        var seen = std.AutoHashMap(usize, void).init(std.debug.global_allocator);
        defer seen.deinit();

        var sy: usize = 0;
        while (sy < self.my) : (sy += 1) {
            var sx: usize = 0;
            while (sx < self.mx) : (sx += 1) {
                if (self.data[sy][sx] == 0) continue;
                // std.debug.warn("S {} {}\n", sx, sy);

                seen.clear();
                var ty: usize = 0;
                while (ty < self.my) : (ty += 1) {
                    var tx: usize = 0;
                    while (tx < self.mx) : (tx += 1) {
                        if (tx == sx and ty == sy) continue;
                        if (self.data[ty][tx] == 0) continue;
                        // std.debug.warn("T {} {}\n", tx, ty);
                        var dir: usize = 0;
                        var dx: usize = 0;
                        if (sx > tx) {
                            dx = sx - tx;
                            dir |= 0x01;
                        } else {
                            dx = tx - sx;
                        }
                        var dy: usize = 0;
                        if (sy > ty) {
                            dy = sy - ty;
                            dir |= 0x10;
                        } else {
                            dy = ty - sy;
                        }
                        const g = gcd(dx, dy);
                        const cx = dx / g;
                        const cy = dy / g;
                        const l = (dir * 10 + cx) * 100 + cy;
                        if (seen.contains(l)) continue;
                        self.data[sy][sx] += 1;
                        if (mc < self.data[sy][sx]) {
                            mx = sx;
                            my = sy;
                            mc = self.data[sy][sx];
                        }
                        _ = seen.put(l, {}) catch unreachable;
                    }
                }
            }
        }
        // std.debug.warn("MIN is {} at {} {}\n", mc - 1, mx, my);
        return mc - 1;
    }

    pub fn scan_and_blast(self: *Board, sx: i32, sy: i32, target: usize) usize {
        var data: [50 * 50]TargetInfo = undefined;
        var pos: usize = 0;
        var y: i32 = 0;
        while (y < @intCast(i32, self.my)) : (y += 1) {
            var x: i32 = 0;
            while (x < @intCast(i32, self.mx)) : (x += 1) {
                if (x == sx and y == sy) continue;
                if (self.data[@intCast(usize, y)][@intCast(usize, x)] == 0) continue;
                const dx = @intToFloat(f64, sx - x);
                const dy = @intToFloat(f64, sy - y);
                var theta = -std.math.atan2(f64, dx, dy);
                if (theta < 0) theta += 2.0 * std.math.pi;
                const a = @floatToInt(i32, theta * 1000.0);
                data[pos].angle = @floatToInt(i32, theta * 1000.0);
                data[pos].x = x;
                data[pos].y = y;
                data[pos].dist = @floatToInt(usize, std.math.absFloat(dx) + std.math.absFloat(dy));
                data[pos].shot = false;
                // std.debug.warn("POS {} = {} {} : {}\n", pos, data[pos].x, data[pos].y, data[pos].a);
                pos += 1;
            }
        }
        std.sort.sort(TargetInfo, data[0..pos], cmpByAngle);

        var seen = std.AutoHashMap(usize, void).init(std.debug.global_allocator);
        defer seen.deinit();
        var shot: usize = 0;
        while (shot < pos) {
            seen.clear();
            var j: usize = 0;
            while (j < pos) : (j += 1) {
                if (data[j].shot) continue;
                // std.debug.warn("POS {} = {} {} : {}\n", j, data[j].x, data[j].y, data[j].a);
                var dir: usize = 0;
                var dx: usize = 0;
                if (sx > data[j].x) {
                    dx = @intCast(usize, sx - data[j].x);
                    dir |= 0x01;
                } else {
                    dx = @intCast(usize, data[j].x - sx);
                }
                var dy: usize = 0;
                if (sy > data[j].y) {
                    dy = @intCast(usize, sy - data[j].y);
                    dir |= 0x10;
                } else {
                    dy = @intCast(usize, data[j].y - sy);
                }
                const g = gcd(dx, dy);
                const cx = dx / g;
                const cy = dy / g;
                const l = (dir * 10 + cx) * 100 + cy;
                if (seen.contains(l)) continue;
                shot += 1;
                // std.debug.warn("SHOT  #{}: {} {}\n", shot, data[j].x, data[j].y);
                data[j].shot = true;
                _ = seen.put(l, {}) catch unreachable;
                if (shot == target) {
                    return @intCast(usize, data[j].x) * 100 + @intCast(usize, data[j].y);
                }
            }
        }
        return 0;
    }
};

test "map1" {
    std.debug.warn("\n");
    var board = Board.init();
    board.add_line(".#..#");
    board.add_line(".....");
    board.add_line("#####");
    board.add_line("....#");
    board.add_line("...##");
    // board.show();

    const result = board.find_best_position();
    assert(result == 8);
}

test "map2" {
    std.debug.warn("\n");
    var board = Board.init();
    board.add_line("......#.#.");
    board.add_line("#..#.#....");
    board.add_line("..#######.");
    board.add_line(".#.#.###..");
    board.add_line(".#..#.....");
    board.add_line("..#....#.#");
    board.add_line("#..#....#.");
    board.add_line(".##.#..###");
    board.add_line("##...#..#.");
    board.add_line(".#....####");
    // board.show();

    const result = board.find_best_position();
    assert(result == 33);
}

test "map3" {
    std.debug.warn("\n");
    var board = Board.init();
    board.add_line("#.#...#.#.");
    board.add_line(".###....#.");
    board.add_line(".#....#...");
    board.add_line("##.#.#.#.#");
    board.add_line("....#.#.#.");
    board.add_line(".##..###.#");
    board.add_line("..#...##..");
    board.add_line("..##....##");
    board.add_line("......#...");
    board.add_line(".####.###.");
    // board.show();

    const result = board.find_best_position();
    assert(result == 35);
}

test "map4" {
    std.debug.warn("\n");
    var board = Board.init();
    board.add_line(".#..#..###");
    board.add_line("####.###.#");
    board.add_line("....###.#.");
    board.add_line("..###.##.#");
    board.add_line("##.##.#.#.");
    board.add_line("....###..#");
    board.add_line("..#.#..#.#");
    board.add_line("#..#.#.###");
    board.add_line(".##...##.#");
    board.add_line(".....#.#..");
    // board.show();

    const result = board.find_best_position();
    assert(result == 41);
}

test "map5" {
    std.debug.warn("\n");
    var board = Board.init();
    board.add_line(".#..##.###...#######");
    board.add_line("##.############..##.");
    board.add_line(".#.######.########.#");
    board.add_line(".###.#######.####.#.");
    board.add_line("#####.##.#.##.###.##");
    board.add_line("..#####..#.#########");
    board.add_line("####################");
    board.add_line("#.####....###.#.#.##");
    board.add_line("##.#################");
    board.add_line("#####.##.###..####..");
    board.add_line("..######..##.#######");
    board.add_line("####.##.####...##..#");
    board.add_line(".#####..#.######.###");
    board.add_line("##...#.##########...");
    board.add_line("#.##########.#######");
    board.add_line(".####.#.###.###.#.##");
    board.add_line("....##.##.###..#####");
    board.add_line(".#.#.###########.###");
    board.add_line("#.#.#.#####.####.###");
    board.add_line("###.##.####.##.#..##");
    // board.show();

    const result = board.find_best_position();
    assert(result == 210);
}

test "scan small" {
    std.debug.warn("\n");
    var board = Board.init();
    board.add_line(".#....#####...#..");
    board.add_line("##...##.#####..##");
    board.add_line("##...#...#.#####.");
    board.add_line("..#.....#...###..");
    board.add_line("..#.#.....#....##");
    // board.show();
    const result = board.scan_and_blast(8, 3, 36);
    assert(result == 1403);
}

test "scan medium" {
    std.debug.warn("\n");
    var board = Board.init();
    board.add_line(".#..##.###...#######");
    board.add_line("##.############..##.");
    board.add_line(".#.######.########.#");
    board.add_line(".###.#######.####.#.");
    board.add_line("#####.##.#.##.###.##");
    board.add_line("..#####..#.#########");
    board.add_line("####################");
    board.add_line("#.####....###.#.#.##");
    board.add_line("##.#################");
    board.add_line("#####.##.###..####..");
    board.add_line("..######..##.#######");
    board.add_line("####.##.####...##..#");
    board.add_line(".#####..#.######.###");
    board.add_line("##...#.##########...");
    board.add_line("#.##########.#######");
    board.add_line(".####.#.###.###.#.##");
    board.add_line("....##.##.###..#####");
    board.add_line(".#.#.###########.###");
    board.add_line("#.#.#.#####.####.###");
    board.add_line("###.##.####.##.#..##");
    // board.show();
    const result = board.scan_and_blast(11, 13, 200);
    assert(result == 802);
}
