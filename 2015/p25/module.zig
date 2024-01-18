const std = @import("std");
const testing = std.testing;

pub const Manual = struct {
    const MANUAL_SEED = 20151125;
    const CODE_MUL = 252533;
    const CODE_MOD = 33554393;

    seed: usize,
    row: usize,
    col: usize,

    pub fn init(seed: usize) Manual {
        return Manual{
            .seed = seed,
            .row = 0,
            .col = 0,
        };
    }

    pub fn initDefault() Manual {
        return Manual.init(MANUAL_SEED);
    }

    pub fn addLine(self: *Manual, line: []const u8) !void {
        var it = std.mem.tokenizeAny(u8, line, " ,.");
        var pos: usize = 0;
        while (it.next()) |chunk| : (pos += 1) {
            switch (pos) {
                15 => self.row = try std.fmt.parseUnsigned(usize, chunk, 10),
                17 => self.col = try std.fmt.parseUnsigned(usize, chunk, 10),
                else => continue,
            }
        }
    }

    pub fn show(self: Manual) void {
        std.debug.print("Manual, row={}, col={}\n", .{ self.row, self.col });
    }

    pub fn getCode(self: Manual) usize {
        return self.getCodeAtPos(self.row, self.col);
    }

    fn getCodeAtPos(self: Manual, r: usize, c: usize) usize {
        const p = self.getSeqFromPos(r, c);
        var code = self.seed;
        for (0..p) |_| {
            code *= CODE_MUL;
            code %= CODE_MOD;
        }
        return code;
    }

    fn getSeqFromPos(_: Manual, r: usize, c: usize) usize {
        const sum = r + c;
        const pos = sum * sum - 3 * r - c;
        return pos / 2; // zero-based
    }
};

test "sample part 1" {
    var manual = Manual.initDefault();
    // manual.show();

    //    |    1         2         3         4         5         6
    // ---+---------+---------+---------+---------+---------+---------+
    //  1 | 20151125  18749137  17289845  30943339  10071777  33511524
    //  2 | 31916031  21629792  16929656   7726640  15514188   4041754
    //  3 | 16080970   8057251   1601130   7981243  11661866  16474243
    //  4 | 24592653  32451966  21345942   9380097  10600672  31527494
    //  5 |    77061  17552253  28094349   6899651   9250759  31663883
    //  6 | 33071741   6796745  25397450  24659492   1534922  27995004

    try testing.expectEqual(@as(usize, 20151125), manual.getCodeAtPos(1, 1));
    try testing.expectEqual(@as(usize, 18749137), manual.getCodeAtPos(1, 2));
    try testing.expectEqual(@as(usize, 17289845), manual.getCodeAtPos(1, 3));
    try testing.expectEqual(@as(usize, 30943339), manual.getCodeAtPos(1, 4));
    try testing.expectEqual(@as(usize, 10071777), manual.getCodeAtPos(1, 5));
    try testing.expectEqual(@as(usize, 33511524), manual.getCodeAtPos(1, 6));
    try testing.expectEqual(@as(usize, 31916031), manual.getCodeAtPos(2, 1));
    try testing.expectEqual(@as(usize, 21629792), manual.getCodeAtPos(2, 2));
    try testing.expectEqual(@as(usize, 16929656), manual.getCodeAtPos(2, 3));
    try testing.expectEqual(@as(usize, 7726640), manual.getCodeAtPos(2, 4));
    try testing.expectEqual(@as(usize, 15514188), manual.getCodeAtPos(2, 5));
    try testing.expectEqual(@as(usize, 4041754), manual.getCodeAtPos(2, 6));
    try testing.expectEqual(@as(usize, 16080970), manual.getCodeAtPos(3, 1));
    try testing.expectEqual(@as(usize, 8057251), manual.getCodeAtPos(3, 2));
    try testing.expectEqual(@as(usize, 1601130), manual.getCodeAtPos(3, 3));
    try testing.expectEqual(@as(usize, 7981243), manual.getCodeAtPos(3, 4));
    try testing.expectEqual(@as(usize, 11661866), manual.getCodeAtPos(3, 5));
    try testing.expectEqual(@as(usize, 16474243), manual.getCodeAtPos(3, 6));
    try testing.expectEqual(@as(usize, 24592653), manual.getCodeAtPos(4, 1));
    try testing.expectEqual(@as(usize, 32451966), manual.getCodeAtPos(4, 2));
    try testing.expectEqual(@as(usize, 21345942), manual.getCodeAtPos(4, 3));
    try testing.expectEqual(@as(usize, 9380097), manual.getCodeAtPos(4, 4));
    try testing.expectEqual(@as(usize, 10600672), manual.getCodeAtPos(4, 5));
    try testing.expectEqual(@as(usize, 31527494), manual.getCodeAtPos(4, 6));
    try testing.expectEqual(@as(usize, 77061), manual.getCodeAtPos(5, 1));
    try testing.expectEqual(@as(usize, 17552253), manual.getCodeAtPos(5, 2));
    try testing.expectEqual(@as(usize, 28094349), manual.getCodeAtPos(5, 3));
    try testing.expectEqual(@as(usize, 6899651), manual.getCodeAtPos(5, 4));
    try testing.expectEqual(@as(usize, 9250759), manual.getCodeAtPos(5, 5));
    try testing.expectEqual(@as(usize, 31663883), manual.getCodeAtPos(5, 6));
    try testing.expectEqual(@as(usize, 33071741), manual.getCodeAtPos(6, 1));
    try testing.expectEqual(@as(usize, 6796745), manual.getCodeAtPos(6, 2));
    try testing.expectEqual(@as(usize, 25397450), manual.getCodeAtPos(6, 3));
    try testing.expectEqual(@as(usize, 24659492), manual.getCodeAtPos(6, 4));
    try testing.expectEqual(@as(usize, 1534922), manual.getCodeAtPos(6, 5));
    try testing.expectEqual(@as(usize, 27995004), manual.getCodeAtPos(6, 6));
}
