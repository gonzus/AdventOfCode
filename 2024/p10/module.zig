const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const SIZE = 50;

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            return .{ .x = x, .y = y };
        }
    };

    use_rating: bool,
    grid: [SIZE][SIZE]u8,
    rows: usize,
    cols: usize,
    seen: std.AutoHashMap(Pos, void),

    pub fn init(allocator: Allocator, use_rating: bool) Module {
        const self = Module{
            .use_rating = use_rating,
            .grid = undefined,
            .rows = 0,
            .cols = 0,
            .seen = std.AutoHashMap(Pos, void).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Module) void {
        self.seen.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        if (self.cols == 0) {
            self.cols = line.len;
        }
        if (self.cols != line.len) {
            return error.JaggedGrid;
        }
        const y = self.rows;
        for (line, 0..) |c, x| {
            self.grid[x][y] = c;
        }
        self.rows += 1;
    }

    fn walkPaths(self: *Module, need: u8, x: usize, y: usize) !usize {
        const value = self.grid[x][y];
        if (value != need) return 0;
        if (value == '9') {
            if (!self.use_rating) {
                const r = try self.seen.getOrPut(Pos.init(x, y));
                if (r.found_existing) return 0;
            }
            return 1;
        }
        const next = need + 1;
        var count: usize = 0;
        if (x > 0) count += try self.walkPaths(next, x - 1, y);
        if (x < self.cols - 1) count += try self.walkPaths(next, x + 1, y);
        if (y > 0) count += try self.walkPaths(next, x, y - 1);
        if (y < self.rows - 1) count += try self.walkPaths(next, x, y + 1);
        return count;
    }

    pub fn getTotalScore(self: *Module) !usize {
        var sum: usize = 0;
        for (0..self.rows) |y| {
            for (0..self.cols) |x| {
                if (!self.use_rating) {
                    self.seen.clearRetainingCapacity();
                }
                sum += try self.walkPaths('0', x, y);
            }
        }
        return sum;
    }
};

test "sample part 1 example 1" {
    const data =
        \\0123
        \\1234
        \\8765
        \\9876
    ;

    var module = Module.init(testing.allocator, false);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalScore();
    const expected = @as(usize, 1);
    try testing.expectEqual(expected, count);
}

test "sample part 1 example 2" {
    const data =
        \\...0...
        \\...1...
        \\...2...
        \\6543456
        \\7.....7
        \\8.....8
        \\9.....9
    ;

    var module = Module.init(testing.allocator, false);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalScore();
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, count);
}

test "sample part 1 example 3" {
    const data =
        \\..90..9
        \\...1.98
        \\...2..7
        \\6543456
        \\765.987
        \\876....
        \\987....
    ;

    var module = Module.init(testing.allocator, false);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalScore();
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, count);
}

test "sample part 1 example 4" {
    const data =
        \\10..9..
        \\2...8..
        \\3...7..
        \\4567654
        \\...8..3
        \\...9..2
        \\.....01
    ;

    var module = Module.init(testing.allocator, false);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalScore();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, count);
}

test "sample part 1" {
    const data =
        \\89010123
        \\78121874
        \\87430965
        \\96549874
        \\45678903
        \\32019012
        \\01329801
        \\10456732
    ;

    var module = Module.init(testing.allocator, false);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalScore();
    const expected = @as(usize, 36);
    try testing.expectEqual(expected, count);
}

test "sample part 2 example 1" {
    const data =
        \\.....0.
        \\..4321.
        \\..5..2.
        \\..6543.
        \\..7..4.
        \\..8765.
        \\..9....
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalScore();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, count);
}

test "sample part 2 example 2" {
    const data =
        \\..90..9
        \\...1.98
        \\...2..7
        \\6543456
        \\765.987
        \\876....
        \\987....
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalScore();
    const expected = @as(usize, 13);
    try testing.expectEqual(expected, count);
}

test "sample part 2 example 3" {
    const data =
        \\012345
        \\123456
        \\234567
        \\345678
        \\4.6789
        \\56789.
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalScore();
    const expected = @as(usize, 227);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\89010123
        \\78121874
        \\87430965
        \\96549874
        \\45678903
        \\32019012
        \\01329801
        \\10456732
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalScore();
    const expected = @as(usize, 81);
    try testing.expectEqual(expected, count);
}
