const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Spreadsheet = struct {
    divide: bool,
    checksum: usize,
    seen: std.ArrayList(usize),

    pub fn init(allocator: Allocator, divide: bool) Spreadsheet {
        return .{
            .divide = divide,
            .checksum = 0,
            .seen = std.ArrayList(usize).init(allocator),
        };
    }

    pub fn deinit(self: *Spreadsheet) void {
        self.seen.deinit();
    }

    pub fn addLine(self: *Spreadsheet, line: []const u8) !void {
        self.seen.clearRetainingCapacity();
        var it = std.mem.tokenizeAny(u8, line, " \t");
        var lo: usize = std.math.maxInt(usize);
        var hi: usize = 0;
        var delta: usize = 0;
        while (it.next()) |chunk| {
            const num = try std.fmt.parseUnsigned(usize, chunk, 10);
            if (self.divide) {
                for (self.seen.items) |s| {
                    var old: usize = s;
                    var cur: usize = num;
                    if (cur < old) std.mem.swap(usize, &cur, &old);
                    if (cur % old == 0) {
                        delta = cur / old;
                    }
                }
                try self.seen.append(num);
            } else {
                if (lo > num) lo = num;
                if (hi < num) hi = num;
            }
        }
        if (!self.divide) {
            delta = hi - lo;
        }
        self.checksum += delta;
    }

    pub fn getChecksum(self: Spreadsheet) usize {
        return self.checksum;
    }
};

test "sample part 1" {
    const data =
        \\5 1 9 5
        \\7 5 3
        \\2 4 6 8
    ;

    var spreadsheet = Spreadsheet.init(testing.allocator, false);
    defer spreadsheet.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try spreadsheet.addLine(line);
    }

    const checksum = spreadsheet.getChecksum();
    const expected = @as(usize, 18);
    try testing.expectEqual(expected, checksum);
}

test "sample part 2" {
    const data =
        \\5 9 2 8
        \\9 4 7 3
        \\3 8 6 5
    ;

    var spreadsheet = Spreadsheet.init(testing.allocator, true);
    defer spreadsheet.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try spreadsheet.addLine(line);
    }

    const checksum = spreadsheet.getChecksum();
    const expected = @as(usize, 9);
    try testing.expectEqual(expected, checksum);
}
