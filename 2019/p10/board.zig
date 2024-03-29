const std = @import("std");
const assert = std.debug.assert;
const allocator = std.testing.allocator;

const TargetInfo = struct {
    angle: f64,
    x: usize,
    y: usize,
    dist: usize,
    shot: bool,
};
fn cmpByAngle(_: void, l: TargetInfo, r: TargetInfo) bool {
    if (l.angle < r.angle) return true;
    if (l.angle > r.angle) return false;
    return l.dist < r.dist;
}

pub const Board = struct {
    maxx: usize,
    maxy: usize,
    data: [50][50]usize,

    pub fn init() Board {
        var self = Board{
            .maxx = 0,
            .maxy = 0,
            .data = undefined,
        };
        return self;
    }

    pub fn deinit(self: Board) void {
        _ = self;
    }

    pub fn add_lines(self: *Board, lines: []const u8) void {
        var it = std.mem.split(u8, lines, "\n");
        while (it.next()) |str| {
            self.add_line(str);
        }
    }

    pub fn add_line(self: *Board, str: []const u8) void {
        var j: usize = 0;
        while (j < str.len) : (j += 1) {
            var c: usize = 0;
            if (str[j] == '#') c = 1;
            self.data[self.maxy][j] = c;
        }
        if (self.maxx < j) {
            self.maxx = j;
        }
        self.maxy += 1;
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
        var y: usize = 0;
        std.debug.warn("BOARD {}x{}\n", self.maxy, self.maxx);
        while (y < self.maxy) : (y += 1) {
            var x: usize = 0;
            std.debug.warn("|");
            while (x < self.maxx) : (x += 1) {
                std.debug.warn("{}", self.data[y][x]);
            }
            std.debug.warn("|\n");
        }
    }

    pub fn find_best_position(self: *Board) usize {
        var minc: usize = 0;
        var minx: usize = 0;
        var miny: usize = 0;

        var seen = std.AutoHashMap(usize, void).init(allocator);
        defer seen.deinit();

        var srcy: usize = 0;
        while (srcy < self.maxy) : (srcy += 1) {
            var srcx: usize = 0;
            while (srcx < self.maxx) : (srcx += 1) {
                if (self.data[srcy][srcx] == 0) continue;

                seen.clearRetainingCapacity();
                var tgty: usize = 0;
                while (tgty < self.maxy) : (tgty += 1) {
                    var tgtx: usize = 0;
                    while (tgtx < self.maxx) : (tgtx += 1) {
                        if (tgtx == srcx and tgty == srcy) continue;
                        if (self.data[tgty][tgtx] == 0) continue;

                        const label = make_label(srcx, srcy, tgtx, tgty);
                        if (seen.contains(label)) continue;

                        self.data[srcy][srcx] += 1;
                        if (minc < self.data[srcy][srcx]) {
                            minx = srcx;
                            miny = srcy;
                            minc = self.data[srcy][srcx];
                        }
                        _ = seen.put(label, {}) catch unreachable;
                    }
                }
            }
        }
        // std.debug.warn("MIN is {} at {} {}\n", minc - 1, minx, miny);
        return minc - 1; // the position itself doesn't count
    }

    pub fn scan_and_blast(self: *Board, srcx: usize, srcy: usize, target: usize) usize {
        var data: [50 * 50]TargetInfo = undefined;
        var pos: usize = 0;
        var y: usize = 0;
        while (y < self.maxy) : (y += 1) {
            var x: usize = 0;
            while (x < self.maxx) : (x += 1) {
                if (x == srcx and y == srcy) continue;
                if (self.data[y][x] == 0) continue;

                // compute theta = atan(dx / dy)
                // in this case we do want the signs for the differences
                // atan returns angles that grow counterclockwise, hence the '-'
                // atan returns negative angles for x<0, hence we add 2*pi then
                const dx = @intToFloat(f64, @intCast(i32, srcx) - @intCast(i32, x));
                const dy = @intToFloat(f64, @intCast(i32, srcy) - @intCast(i32, y));
                var theta = -std.math.atan2(f64, dx, dy);
                if (theta < 0) theta += 2.0 * std.math.pi;

                data[pos].angle = theta;
                data[pos].x = x;
                data[pos].y = y;
                data[pos].dist = @floatToInt(usize, std.math.absFloat(dx)) + @floatToInt(usize, std.math.absFloat(dy));
                data[pos].shot = false;
                // std.debug.warn("POS {} = {} {} : {}\n", pos, data[pos].x, data[pos].y, data[pos].a);
                pos += 1;
            }
        }

        // we can now sort by angle; for positions with the same angle, the lowest distance wins
        std.sort.sort(TargetInfo, data[0..pos], {}, cmpByAngle);

        // we can now circle around as many times as necessary to hit the desired target
        var seen = std.AutoHashMap(usize, void).init(allocator);
        defer seen.deinit();
        var shot: usize = 0;
        while (shot < pos) {
            // on each turn we "forget" the previous targets
            seen.clearRetainingCapacity();
            var j: usize = 0;
            while (j < pos) : (j += 1) {
                // skip positions we have already shot
                if (data[j].shot) continue;

                const label = make_label(srcx, srcy, data[j].x, data[j].y);
                if (seen.contains(label)) continue;
                _ = seen.put(label, {}) catch unreachable;

                // we have not shot yet in this direction; do it!
                shot += 1;
                // std.debug.warn("SHOT  #{}: {} {}\n", shot, data[j].x, data[j].y);
                data[j].shot = true;
                if (shot == target) {
                    return data[j].x * 100 + data[j].y;
                }
            }
        }
        return 0;
    }

    fn make_label(srcx: usize, srcy: usize, tgtx: usize, tgty: usize) usize {
        var dir: usize = 0;
        var dx: usize = 0;
        if (srcx > tgtx) {
            dx = srcx - tgtx;
            dir |= 0x01;
        } else {
            dx = tgtx - srcx;
        }
        var dy: usize = 0;
        if (srcy > tgty) {
            dy = srcy - tgty;
            dir |= 0x10;
        } else {
            dy = tgty - srcy;
        }
        const common = gcd(dx, dy);
        const canonx = dx / common;
        const canony = dy / common;
        const label = (dir * 10 + canonx) * 100 + canony;
        return label;
    }
};

test "best position 1" {
    const data: []const u8 =
        \\.#..#
        \\.....
        \\#####
        \\....#
        \\...##
    ;
    var board = Board.init();
    board.add_lines(data);
    // board.show();

    const result = board.find_best_position();
    assert(result == 8);
}

test "best position 2" {
    const data: []const u8 =
        \\......#.#.
        \\#..#.#....
        \\..#######.
        \\.#.#.###..
        \\.#..#.....
        \\..#....#.#
        \\#..#....#.
        \\.##.#..###
        \\##...#..#.
        \\.#....####
    ;
    var board = Board.init();
    board.add_lines(data);
    // board.show();

    const result = board.find_best_position();
    assert(result == 33);
}

test "best position 3" {
    const data: []const u8 =
        \\#.#...#.#.
        \\.###....#.
        \\.#....#...
        \\##.#.#.#.#
        \\....#.#.#.
        \\.##..###.#
        \\..#...##..
        \\..##....##
        \\......#...
        \\.####.###.
    ;
    var board = Board.init();
    board.add_lines(data);
    // board.show();

    const result = board.find_best_position();
    assert(result == 35);
}

test "best position 4" {
    const data: []const u8 =
        \\.#..#..###
        \\####.###.#
        \\....###.#.
        \\..###.##.#
        \\##.##.#.#.
        \\....###..#
        \\..#.#..#.#
        \\#..#.#.###
        \\.##...##.#
        \\.....#.#..
    ;
    var board = Board.init();
    board.add_lines(data);
    // board.show();

    const result = board.find_best_position();
    assert(result == 41);
}

test "best position 5" {
    const data: []const u8 =
        \\.#..##.###...#######
        \\##.############..##.
        \\.#.######.########.#
        \\.###.#######.####.#.
        \\#####.##.#.##.###.##
        \\..#####..#.#########
        \\####################
        \\#.####....###.#.#.##
        \\##.#################
        \\#####.##.###..####..
        \\..######..##.#######
        \\####.##.####...##..#
        \\.#####..#.######.###
        \\##...#.##########...
        \\#.##########.#######
        \\.####.#.###.###.#.##
        \\....##.##.###..#####
        \\.#.#.###########.###
        \\#.#.#.#####.####.###
        \\###.##.####.##.#..##
    ;
    var board = Board.init();
    board.add_lines(data);
    // board.show();

    const result = board.find_best_position();
    assert(result == 210);
}

test "scan small" {
    const data: []const u8 =
        \\.#....#####...#..
        \\##...##.#####..##
        \\##...#...#.#####.
        \\..#.....#...###..
        \\..#.#.....#....##
    ;
    var board = Board.init();
    board.add_lines(data);
    // board.show();
    const result = board.scan_and_blast(8, 3, 36);
    assert(result == 1403);
}

test "scan medium" {
    const data: []const u8 =
        \\.#..##.###...#######
        \\##.############..##.
        \\.#.######.########.#
        \\.###.#######.####.#.
        \\#####.##.#.##.###.##
        \\..#####..#.#########
        \\####################
        \\#.####....###.#.#.##
        \\##.#################
        \\#####.##.###..####..
        \\..######..##.#######
        \\####.##.####...##..#
        \\.#####..#.######.###
        \\##...#.##########...
        \\#.##########.#######
        \\.####.#.###.###.#.##
        \\....##.##.###..#####
        \\.#.#.###########.###
        \\#.#.#.#####.####.###
        \\###.##.####.##.#..##
    ;
    var board = Board.init();
    board.add_lines(data);
    // board.show();
    const result = board.scan_and_blast(11, 13, 200);
    assert(result == 802);
}
