const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Policy = struct {
    anagram: bool,
    valid: usize,
    strtab: StringTable,

    pub fn init(allocator: Allocator, anagram: bool) Policy {
        return .{
            .anagram = anagram,
            .valid = 0,
            .strtab = StringTable.init(allocator),
        };
    }

    pub fn deinit(self: *Policy) void {
        self.strtab.deinit();
    }

    pub fn addLine(self: *Policy, line: []const u8) !void {
        var valid = true;
        self.strtab.clear();
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        while (it.next()) |chunk| {
            var buf: [100]u8 = undefined;
            var word: []const u8 = chunk;
            if (self.anagram) {
                std.mem.copyForwards(u8, &buf, chunk);
                std.sort.heap(u8, buf[0..chunk.len], {}, std.sort.asc(u8));
                word = buf[0..chunk.len];
            }
            if (self.strtab.contains(word)) {
                valid = false;
                break;
            }
            _ = try self.strtab.add(word);
        }
        if (valid) self.valid += 1;
    }

    pub fn getValidCount(self: Policy) usize {
        return self.valid;
    }
};

test "sample part 1" {
    const data =
        \\aa bb cc dd ee
        \\aa bb cc dd aa
        \\aa bb cc dd aaa
    ;

    var policy = Policy.init(testing.allocator, false);
    defer policy.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try policy.addLine(line);
    }

    const steps = policy.getValidCount();
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, steps);
}

test "sample part 2" {
    const data =
        \\abcde fghij
        \\abcde xyz ecdab
        \\a ab abc abd abf abj
        \\iiii oiii ooii oooi oooo
        \\oiii ioii iioi iiio
    ;

    var policy = Policy.init(testing.allocator, true);
    defer policy.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try policy.addLine(line);
    }

    const steps = policy.getValidCount();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, steps);
}
