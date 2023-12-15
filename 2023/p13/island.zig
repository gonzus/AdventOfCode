const std = @import("std");
const testing = std.testing;
const Grid = @import("./util/grid.zig").Grid;
const Pos = @import("./util/grid.zig").Pos;

const Allocator = std.mem.Allocator;

pub const Pattern = struct {
    const MULTIPLIER_ROWS = 100;
    const MULTIPLIER_COLS = 1;

    const Data = Grid(u8);

    allocator: Allocator,
    smudges: usize,
    data: Data,
    summary: usize,

    pub fn init(allocator: Allocator, smudges: usize) Pattern {
        var self = Pattern{
            .allocator = allocator,
            .smudges = smudges,
            .data = Data.init(allocator, '.'),
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

        try self.data.ensureCols(line.len);
        try self.data.ensureExtraRow();
        const y = self.data.rows();
        for (line, 0..) |c, x| {
            try self.data.set(x, y, c);
        }
    }

    pub fn getSummary(self: *Pattern) !usize {
        try self.process(); // last block may be pending
        return self.summary;
    }

    fn searchMirrors(self: Pattern) usize {
        for (1..self.data.cols()) |x| {
            const min = @min(x, self.data.cols() - x);
            var diffs: usize = 0;
            for (0..self.data.rows()) |y| {
                for (0..min) |m| {
                    const dl = self.data.get(x - 1 - m, y);
                    const dr = self.data.get(x + m, y);
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

        for (1..self.data.rows()) |y| {
            const min = @min(y, self.data.rows() - y);
            var diffs: usize = 0;
            for (0..self.data.cols()) |x| {
                for (0..min) |m| {
                    const dt = self.data.get(x, y - 1 - m);
                    const db = self.data.get(x, y + m);
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
        if (self.data.rows() == 0) {
            return;
        }

        self.summary += self.searchMirrors();
        self.data.clear();
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
