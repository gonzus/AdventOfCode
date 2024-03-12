const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Warehouse = struct {
    const StringId = StringTable.StringId;

    strtab: StringTable,
    words: std.ArrayList(StringId),
    buf: [100]u8,
    len: usize,

    pub fn init(allocator: Allocator) Warehouse {
        return .{
            .strtab = StringTable.init(allocator),
            .words = std.ArrayList(StringId).init(allocator),
            .buf = undefined,
            .len = 0,
        };
    }

    pub fn deinit(self: *Warehouse) void {
        self.words.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Warehouse, line: []const u8) !void {
        const id = try self.strtab.add(line);
        try self.words.append(id);
    }

    pub fn getChecksum(self: Warehouse) usize {
        var count2: usize = 0;
        var count3: usize = 0;
        for (self.words.items) |w| {
            const word_opt = self.strtab.get_str(w);
            if (word_opt) |word| {
                var chars = [_]usize{0} ** 26;
                for (word) |c| {
                    chars[c - 'a'] += 1;
                }
                var n2: usize = 0;
                var n3: usize = 0;
                for (&chars) |c| {
                    if (c == 2) n2 += 1;
                    if (c == 3) n3 += 1;
                }
                if (n2 >= 1) {
                    count2 += 1;
                }
                if (n3 >= 1) {
                    count3 += 1;
                }
            }
        }
        return count2 * count3;
    }

    pub fn getCommonLeters(self: *Warehouse) []const u8 {
        self.len = 0;
        SEARCH: for (0..self.words.items.len) |p0| {
            const w0_opt = self.strtab.get_str(self.words.items[p0]);
            if (w0_opt) |w0| {
                for (p0 + 1..self.words.items.len) |p1| {
                    const w1_opt = self.strtab.get_str(self.words.items[p1]);
                    if (w1_opt) |w1| {
                        if (w0.len != w1.len) continue;
                        var diff_pos: usize = 0;
                        var diff_tot: usize = 0;
                        for (w0, w1, 0..) |c1, c2, p| {
                            if (c1 == c2) continue;
                            diff_pos = p;
                            diff_tot += 1;
                        }
                        if (diff_tot == 1) {
                            for (w0, 0..) |c, p| {
                                if (p == diff_pos) continue;
                                self.buf[self.len] = c;
                                self.len += 1;
                            }
                            break :SEARCH;
                        }
                    }
                }
            }
        }
        return self.buf[0..self.len];
    }
};

test "sample part 1" {
    const data =
        \\abcdef
        \\bababc
        \\abbcde
        \\abcccd
        \\aabcdd
        \\abcdee
        \\ababab
    ;

    var warehouse = Warehouse.init(std.testing.allocator);
    defer warehouse.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try warehouse.addLine(line);
    }

    const checksum = warehouse.getChecksum();
    const expected = @as(usize, 12);
    try testing.expectEqual(expected, checksum);
}

test "sample part 2" {
    const data =
        \\abcde
        \\fghij
        \\klmno
        \\pqrst
        \\fguij
        \\axcye
        \\wvxyz
    ;

    var warehouse = Warehouse.init(std.testing.allocator);
    defer warehouse.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try warehouse.addLine(line);
    }

    const text = warehouse.getCommonLeters();
    const expected = "fgij";
    try testing.expectEqualStrings(expected, text);
}
