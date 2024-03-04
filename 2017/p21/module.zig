const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Canvas = struct {
    // largest piece is 4x4 => 16 bits
    const Mask = u16;
    const Rules = std.AutoHashMap(Mask, Mask);

    const SIZE = 10;
    const START = ".#./..#/###";

    const Grid = struct {
        data: [SIZE][SIZE]u8,
        size: usize,

        pub fn init(size: usize) Grid {
            return .{ .data = undefined, .size = size };
        }

        pub fn parse(self: *Grid, str: []const u8) void {
            var size: usize = 0;
            var it = std.mem.tokenizeScalar(u8, str, '/');
            while (it.next()) |chunk| : (size += 1) {
                for (chunk, 0..) |c, p| {
                    self.data[p][size] = c;
                }
            }
            self.size = size;
        }

        pub fn encode(self: Grid, ox: usize, oy: usize, os: usize) Mask {
            var mask: Mask = 0;
            for (oy..oy + os) |y| {
                for (ox..ox + os) |x| {
                    mask <<= 1;
                    if (self.data[x][y] == '#') mask |= 1;
                }
            }
            return mask;
        }

        pub fn encodeAll(self: Grid) Mask {
            return self.encode(0, 0, self.size);
        }

        pub fn decode(self: *Grid, mask: Mask, ox: usize, oy: usize, os: usize) void {
            for (oy..oy + os) |y| {
                for (ox..ox + os) |x| {
                    self.data[x][y] = '.';
                }
            }
            var m = mask;
            var x: usize = ox + os - 1;
            var y: usize = oy + os - 1;
            while (m > 0) : (m >>= 1) {
                if (m & 0x1 > 0) {
                    self.data[x][y] = '#';
                }
                if (x > ox) {
                    x -= 1;
                } else {
                    x = ox + os - 1;
                    if (y > oy) {
                        y -= 1;
                    }
                }
            }
            self.size = os;
        }

        pub fn decodeAll(self: *Grid, mask: Mask) void {
            self.decode(mask, 0, 0, self.size);
        }

        pub fn rotate(self: *Grid) void {
            const s1 = self.size - 1;
            const m = self.size / 2;
            for (0..m) |x| {
                for (x..s1 - x) |y| {
                    const t = self.data[x][y];
                    self.data[x][y] = self.data[y][s1 - x];
                    self.data[y][s1 - x] = self.data[s1 - x][s1 - y];
                    self.data[s1 - x][s1 - y] = self.data[s1 - y][x];
                    self.data[s1 - y][x] = t;
                }
            }
        }

        pub fn flip(self: *Grid) void {
            const s1 = self.size - 1;
            const m = self.size / 2;
            for (0..self.size) |y| {
                for (0..m) |x| {
                    const t = self.data[x][y];
                    self.data[x][y] = self.data[s1 - x][y];
                    self.data[s1 - x][y] = t;
                }
            }
        }

        fn countOn(self: Grid) usize {
            var count: usize = 0;
            for (0..self.size) |y| {
                for (0..self.size) |x| {
                    if (self.data[x][y] != '#') continue;
                    count += 1;
                }
            }
            return count;
        }
    };

    const State = struct {
        mask: Mask,
        size: usize,
        left: usize,
    };

    rules2: Rules,
    rules3: Rules,
    cache: std.AutoHashMap(State, usize),

    pub fn init(allocator: Allocator) Canvas {
        return .{
            .rules2 = Rules.init(allocator),
            .rules3 = Rules.init(allocator),
            .cache = std.AutoHashMap(State, usize).init(allocator),
        };
    }

    pub fn deinit(self: *Canvas) void {
        self.cache.deinit();
        self.rules3.deinit();
        self.rules2.deinit();
    }

    pub fn addLine(self: *Canvas, line: []const u8) !void {
        var it = std.mem.tokenizeSequence(u8, line, " => ");

        var sg = Grid.init(0);
        sg.parse(it.next().?);
        if (sg.size < 2 or sg.size > 3) return error.RuleTooBig;

        var tg = Grid.init(0);
        tg.parse(it.next().?);
        if (sg.size + 1 != tg.size) return error.InconsistentRule;

        const tm = tg.encodeAll();
        // There are in total 8 possible variations and we get them all with four rotations and two flips per rotation
        // https://en.wikipedia.org/wiki/Group_(mathematics)#Second_example:_a_symmetry_group
        for (0..4) |_| {
            sg.rotate();
            for (0..2) |_| {
                sg.flip();
                const sm = sg.encodeAll();
                if (sg.size == 2) {
                    try self.rules2.put(sm, tm);
                    continue;
                }
                if (sg.size == 3) {
                    try self.rules3.put(sm, tm);
                    continue;
                }
            }
        }
    }

    pub fn runIterations(self: *Canvas, iter: usize) !usize {
        var grid = Grid.init(0);
        grid.parse(START);
        return self.walk(grid, iter);
    }

    const Error = error{ InvalidSize, InvalidSource, OutOfMemory };

    fn walk(self: *Canvas, grid: Grid, left: usize) Error!usize {
        const state = State{ .mask = grid.encodeAll(), .size = grid.size, .left = left };
        const c = self.cache.get(state);
        if (c) |count| {
            return count;
        }

        var count: usize = 0;
        defer self.cache.put(state, count) catch @panic("SOB");

        if (left == 0) {
            count = grid.countOn();
            return count;
        }

        if (grid.size % 2 == 0) {
            // must decode all blocks and continue
            const blocks = grid.size / 2;
            var next = Grid.init(0);
            for (0..blocks) |y| {
                for (0..blocks) |x| {
                    const src = grid.encode(2 * x, 2 * y, 2);
                    const t = self.rules2.get(src);
                    if (t) |tgt| {
                        next.decode(tgt, 3 * x, 3 * y, 3);
                    } else {
                        return error.InvalidSource;
                    }
                }
            }
            next.size = blocks * 3;
            count += try self.walk(next, left - 1);
            return count;
        }

        if (grid.size % 3 == 0) {
            // can decode each block separately
            const blocks = grid.size / 3;
            var next = Grid.init(4);
            for (0..blocks) |y| {
                for (0..blocks) |x| {
                    const src = grid.encode(3 * x, 3 * y, 3);
                    const t = self.rules3.get(src);
                    if (t) |tgt| {
                        next.decodeAll(tgt);
                        count += try self.walk(next, left - 1);
                    } else {
                        return error.InvalidSource;
                    }
                }
            }
            return count;
        }

        return error.InvalidSize;
    }
};

test "sample part 1" {
    const data =
        \\../.# => ##./#../...
        \\.#./..#/### => #..#/..../..../#..#
    ;

    var canvas = Canvas.init(std.testing.allocator);
    defer canvas.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try canvas.addLine(line);
    }

    const bits = try canvas.runIterations(2);
    const expected = @as(usize, 12);
    try testing.expectEqual(expected, bits);
}
