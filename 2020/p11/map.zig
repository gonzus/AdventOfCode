const std = @import("std");
const testing = std.testing;

const allocator = std.heap.page_allocator;

pub const Map = struct {
    rows: usize,
    cols: usize,
    cells: [2]std.AutoHashMap(Pos, Tile),
    curr: usize,
    next: usize,
    immediate: bool,

    pub const Tile = enum(u8) {
        Floor = '.',
        Empty = 'L',
        Used = '#',
    };

    pub const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            return Pos{
                .x = x,
                .y = y,
            };
        }
    };

    pub fn init(immediate: bool) Map {
        var self = Map{
            .rows = 0,
            .cols = 0,
            .cells = undefined,
            .curr = 0,
            .next = 1,
            .immediate = immediate,
        };
        self.cells[0] = std.AutoHashMap(Pos, Tile).init(allocator);
        self.cells[1] = std.AutoHashMap(Pos, Tile).init(allocator);
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.cells[1].deinit();
        self.cells[0].deinit();
    }

    pub fn add_line(self: *Map, line: []const u8) void {
        if (self.cols == 0) {
            self.cols = line.len;
        }
        if (self.cols != line.len) {
            @panic("jagged map");
        }
        var x: usize = 0;
        while (x < self.cols) : (x += 1) {
            const tile = switch (line[x]) {
                '.' => Tile.Floor,
                'L' => Tile.Empty,
                '#' => Tile.Used,
                else => @panic("TILE"),
            };
            if (tile == Tile.Floor) continue;
            const pos = Pos.init(x, self.rows);
            _ = self.cells[self.curr].put(pos, tile) catch unreachable;
        }
        self.rows += 1;
    }

    pub fn show(self: Map) void {
        std.debug.warn("MAP: {} x {}\n", .{ self.rows, self.cols });
        var y: usize = 0;
        while (y < self.rows) : (y += 1) {
            std.debug.warn("{:4} | ", .{y});
            var x: usize = 0;
            while (x < self.cols) : (x += 1) {
                var label: u8 = '.';
                const pos = Pos.init(x, y);
                const found = self.cells[self.curr].get(pos);
                if (found) |t| {
                    label = switch (t) {
                        Tile.Floor => '.',
                        Tile.Empty => 'L',
                        Tile.Used => '#',
                    };
                }
                std.debug.warn("{c}", .{label});
            }
            std.debug.warn("\n", .{});
        }
    }

    pub fn step(self: *Map) bool {
        var y: usize = 0;
        while (y < self.rows) : (y += 1) {
            var x: usize = 0;
            while (x < self.cols) : (x += 1) {
                const pos = Pos.init(x, y);
                if (self.cells[self.next].contains(pos)) {
                    _ = self.cells[self.next].remove(pos);
                }
                if (!self.cells[self.curr].contains(pos)) continue;
                const tile = self.cells[self.curr].get(pos).?;
                if (tile == Tile.Floor) continue;
                const occupied = self.countAround(pos);
                var future = tile;
                if (tile == Tile.Empty and occupied == 0) {
                    future = Tile.Used;
                }
                const top: usize = if (self.immediate) 4 else 5;
                if (tile == Tile.Used and occupied >= top) {
                    future = Tile.Empty;
                }
                _ = self.cells[self.next].put(pos, future) catch unreachable;
            }
        }
        const stable = self.isStable();
        if (!stable) {
            self.curr = 1 - self.curr;
            self.next = 1 - self.next;
        }
        return stable;
    }

    pub fn run_until_stable(self: *Map) usize {
        while (true) {
            const equal = self.step();
            if (equal) break;
        }
        var count: usize = 0;
        var y: usize = 0;
        while (y < self.rows) : (y += 1) {
            var x: usize = 0;
            while (x < self.cols) : (x += 1) {
                const pos = Pos.init(x, y);
                if (self.cells[self.curr].get(pos)) |t| {
                    if (t == Tile.Used) {
                        count += 1;
                    }
                }
            }
        }
        return count;
    }

    fn get_delta(dx: isize, dy: isize) usize {
        return @intCast(usize, dy + 1) * 3 + @intCast(usize, dx + 1);
    }

    fn countAround(self: *Map, pos: Pos) usize {
        var count: usize = 0;
        var dy: isize = -1;
        while (dy <= 1) : (dy += 1) {
            var dx: isize = -1;
            while (dx <= 1) : (dx += 1) {
                if (dy == 0 and dx == 0) continue;

                var sy = @intCast(isize, pos.y);
                var sx = @intCast(isize, pos.x);
                var diff: usize = 0;
                while (true) : (diff += 1) {
                    if (self.immediate and diff >= 1) break;
                    sy += dy;
                    sx += dx;
                    if (sy < 0 or sy >= self.rows) break;
                    if (sx < 0 or sx >= self.cols) break;

                    const ny = @intCast(usize, sy);
                    const nx = @intCast(usize, sx);
                    const np = Pos.init(nx, ny);
                    if (!self.cells[self.curr].contains(np)) continue;
                    const nt = self.cells[self.curr].get(np).?;
                    if (nt == Tile.Floor) continue;
                    if (nt == Tile.Used) count += 1;
                    break;
                }
            }
        }
        return count;
    }

    fn isStable(self: *Map) bool {
        var y: usize = 0;
        while (y < self.rows) : (y += 1) {
            var x: usize = 0;
            while (x < self.cols) : (x += 1) {
                const pos = Pos.init(x, y);
                var tl = Tile.Floor;
                if (self.cells[self.curr].get(pos)) |t| {
                    tl = t;
                }
                var tr = Tile.Floor;
                if (self.cells[self.next].get(pos)) |t| {
                    tr = t;
                }
                if (tl != tr) {
                    return false;
                }
            }
        }
        return true;
    }
};

test "sample immediate" {
    const data: []const u8 =
        \\L.LL.LL.LL
        \\LLLLLLL.LL
        \\L.L.L..L..
        \\LLLL.LL.LL
        \\L.LL.LL.LL
        \\L.LLLLL.LL
        \\..L.L.....
        \\LLLLLLLLLL
        \\L.LLLLLL.L
        \\L.LLLLL.LL
    ;

    // #.##.##.##
    // #######.##
    // #.#.#..#..
    // ####.##.##
    // #.##.##.##
    // #.#####.##
    // ..#.#.....
    // ##########
    // #.######.#
    // #.#####.##
    // After a second round, the seats with four or more occupied adjacent seats become empty again:
    //
    // #.LL.L#.##
    // #LLLLLL.L#
    // L.L.L..L..
    // #LLL.LL.L#
    // #.LL.LL.LL
    // #.LLLL#.##
    // ..L.L.....
    // #LLLLLLLL#
    // #.LLLLLL.L
    // #.#LLLL.##
    // This process continues for three more rounds:
    //
    // #.##.L#.##
    // #L###LL.L#
    // L.#.#..#..
    // #L##.##.L#
    // #.##.LL.LL
    // #.###L#.##
    // ..#.#.....
    // #L######L#
    // #.LL###L.L
    // #.#L###.##
    // #.#L.L#.##
    // #LLL#LL.L#
    // L.L.L..#..
    // #LLL.##.L#
    // #.LL.LL.LL
    // #.LL#L#.##
    // ..L.L.....
    // #L#LLLL#L#
    // #.LLLLLL.L
    // #.#L#L#.##
    // #.#L.L#.##
    // #LLL#LL.L#
    // L.#.L..#..
    // #L##.##.L#
    // #.#L.LL.LL
    // #.#L#L#.##
    // ..L.L.....
    // #L#L##L#L#
    // #.LLLLLL.L
    // #.#L#L#.##

    var map = Map.init(true);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        map.add_line(line);
    }
    map.show();

    // var equal: bool = false;

    // equal = map.step();
    // map.show();
    // try testing.expect(!equal);

    // equal = map.step();
    // map.show();
    // try testing.expect(!equal);

    // equal = map.step();
    // map.show();
    // try testing.expect(!equal);

    // equal = map.step();
    // map.show();
    // try testing.expect(!equal);

    // equal = map.step();
    // map.show();
    // try testing.expect(!equal);

    // equal = map.step();
    // map.show();
    // try testing.expect(equal);

    const count = map.run_until_stable();
    try testing.expect(count == 37);
}

test "sample ranged" {
    const data: []const u8 =
        \\L.LL.LL.LL
        \\LLLLLLL.LL
        \\L.L.L..L..
        \\LLLL.LL.LL
        \\L.LL.LL.LL
        \\L.LLLLL.LL
        \\..L.L.....
        \\LLLLLLLLLL
        \\L.LLLLLL.L
        \\L.LLLLL.LL
    ;

    var map = Map.init(false);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        map.add_line(line);
    }
    map.show();

    // var equal: bool = false;

    // equal = map.step();
    // map.show();
    // try testing.expect(!equal);

    // equal = map.step();
    // map.show();
    // try testing.expect(!equal);

    // equal = map.step();
    // map.show();
    // try testing.expect(!equal);

    // equal = map.step();
    // map.show();
    // try testing.expect(!equal);

    // equal = map.step();
    // map.show();
    // try testing.expect(!equal);

    // equal = map.step();
    // map.show();
    // try testing.expect(!equal);

    // equal = map.step();
    // map.show();
    // try testing.expect(equal);

    const count = map.run_until_stable();
    try testing.expect(count == 26);
}
