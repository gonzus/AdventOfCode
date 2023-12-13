const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Pattern = struct {
    const MULTIPLIER_ROWS = 100;
    const MULTIPLIER_COLS = 1;

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            var self = Pos{ .x = x, .y = y };
            return self;
        }
    };

    allocator: Allocator,
    smudges: usize,
    rows: usize,
    cols: usize,
    data: std.AutoHashMap(Pos, u8),
    summary: usize,

    pub fn init(allocator: Allocator, smudges: usize) Pattern {
        var self = Pattern{
            .allocator = allocator,
            .smudges = smudges,
            .rows = 0,
            .cols = 0,
            .data = std.AutoHashMap(Pos, u8).init(allocator),
            .summary = 0,
        };
        return self;
    }

    pub fn deinit(self: *Pattern) void {
        self.data.deinit();
    }

    pub fn addLine(self: *Pattern, line: []const u8) !void {
        if (line.len == 0) {
            try self.process();
            return;
        }

        if (self.cols < line.len) {
            self.cols = line.len;
        }
        for (line, 0..) |c, x| {
            const p = Pos.init(x, self.rows);
            _ = try self.data.getOrPutValue(p, c);
        }
        self.rows += 1;
    }

    pub fn getSummary(self: *Pattern) !usize {
        try self.process(); // last block may be pending
        return self.summary;
    }

    fn searchMirrors(self: Pattern) usize {
        for (1..self.cols) |x| {
            const min = @min(x, self.cols - x);
            var diffs: usize = 0;
            for (0..self.rows) |y| {
                for (0..min) |m| {
                    const pl = Pos.init(x - 1 - m, y);
                    const pr = Pos.init(x + m, y);
                    // std.debug.print("COL {}, CMP {} vs {}\n", .{ x, pl, pr });
                    const dl = self.data.get(pl) orelse unreachable;
                    const dr = self.data.get(pr) orelse unreachable;
                    if (dl != dr) {
                        diffs += 1;
                    }
                }
            }
            if (diffs == self.smudges) {
                // std.debug.print("FOUND COL {}\n", .{x});
                return x * MULTIPLIER_COLS;
            }
        }

        for (1..self.rows) |y| {
            const min = @min(y, self.rows - y);
            var diffs: usize = 0;
            for (0..self.cols) |x| {
                for (0..min) |m| {
                    const pt = Pos.init(x, y - 1 - m);
                    const pb = Pos.init(x, y + m);
                    // std.debug.print("ROW {}, CMP {} vs {}\n", .{ y, pt, pb });
                    const dt = self.data.get(pt) orelse unreachable;
                    const db = self.data.get(pb) orelse unreachable;
                    if (dt != db) {
                        diffs += 1;
                    }
                }
            }
            if (diffs == self.smudges) {
                // std.debug.print("FOUND ROW {}\n", .{y});
                return y * MULTIPLIER_ROWS;
            }
        }

        return 0;
    }

    fn process(self: *Pattern) !void {
        if (self.rows == 0) {
            return;
        }

        self.summary += self.searchMirrors();
        self.data.clearRetainingCapacity();
        self.rows = 0;
        self.cols = 0;
    }
};

test "sample part 1" {
    const data =
        \\#.##..##.
        \\..#.##.#.
        \\##......#
        \\##......#
        \\..#.##.#.
        \\..##..##.
        \\#.#.##.#.
        \\
        \\#...##..#
        \\#....#..#
        \\..##..###
        \\#####.##.
        \\#####.##.
        \\..##..###
        \\#....#..#
    ;

    var pattern = Pattern.init(std.testing.allocator, 0);
    defer pattern.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try pattern.addLine(line);
    }

    const summary = try pattern.getSummary();
    const expected = @as(usize, 405);
    try testing.expectEqual(expected, summary);
}

test "sample part 2" {
    const data =
        \\#.##..##.
        \\..#.##.#.
        \\##......#
        \\##......#
        \\..#.##.#.
        \\..##..##.
        \\#.#.##.#.
        \\
        \\#...##..#
        \\#....#..#
        \\..##..###
        \\#####.##.
        \\#####.##.
        \\..##..###
        \\#....#..#
    ;

    var pattern = Pattern.init(std.testing.allocator, 1);
    defer pattern.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try pattern.addLine(line);
    }

    const summary = try pattern.getSummary();
    const expected = @as(usize, 400);
    try testing.expectEqual(expected, summary);
}
