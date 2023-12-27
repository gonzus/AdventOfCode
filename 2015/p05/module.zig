const std = @import("std");
const testing = std.testing;
const Pos = @import("./util/grid.zig").Pos;

const Allocator = std.mem.Allocator;

pub const Text = struct {
    allocator: Allocator,
    ridiculous: bool,
    nice_count: usize,

    pub fn init(allocator: Allocator, ridiculous: bool) !Text {
        const self = Text{
            .allocator = allocator,
            .ridiculous = ridiculous,
            .nice_count = 0,
        };
        return self;
    }

    fn isNiceWithRidiculuousRules(self: Text, text: []const u8) !bool {
        _ = self;
        var counts = [_]usize{0} ** 26;
        var doubles: usize = 0;
        var forbidden: usize = 0;
        var c1: u8 = 0;
        for (text) |c0| {
            counts[c0 - 'a'] += 1;
            if (c1 == c0) {
                doubles += 1;
            }
            if (c1 == 'a' and c0 == 'b') {
                forbidden += 1;
            }
            if (c1 == 'c' and c0 == 'd') {
                forbidden += 1;
            }
            if (c1 == 'p' and c0 == 'q') {
                forbidden += 1;
            }
            if (c1 == 'x' and c0 == 'y') {
                forbidden += 1;
            }
            c1 = c0;
        }
        const VOWELS = [_]u8{ 'a', 'e', 'i', 'o', 'u' };
        var vowels: usize = 0;
        for (VOWELS) |v| {
            vowels += counts[v - 'a'];
        }
        if (doubles <= 0) return false;
        if (forbidden > 0) return false;
        if (vowels < 3) return false;
        return true;
    }

    fn isNiceWithBetterRules(self: Text, text: []const u8) !bool {
        const Double = [2]u8;
        var doubles = std.AutoHashMap(Double, usize).init(self.allocator);
        defer doubles.deinit();
        var mirrors: usize = 0;
        var last_double: usize = 0;
        var c2: u8 = 0;
        var c1: u8 = 0;
        for (text, 0..) |c0, p0| {
            if (c1 != 0) {
                if (c2 != c1 or c1 != c0 or p0 - last_double >= 2) {
                    const d = [_]u8{ c1, c0 };
                    const r = try doubles.getOrPutValue(d, 0);
                    r.value_ptr.* += 1;
                    last_double = p0;
                }
            }
            if (c2 == c0) {
                mirrors += 1;
            }
            c2 = c1;
            c1 = c0;
        }
        var multi_doubles: usize = 0;
        var it = doubles.valueIterator();
        while (it.next()) |v| {
            if (v.* <= 1) continue;
            multi_doubles += 1;
        }
        if (mirrors == 0) return false;
        if (multi_doubles == 0) return false;
        return true;
    }

    fn isNice(self: *Text, text: []const u8) !bool {
        if (self.ridiculous) {
            return try self.isNiceWithRidiculuousRules(text);
        } else {
            return try self.isNiceWithBetterRules(text);
        }
    }

    pub fn addLine(self: *Text, line: []const u8) !void {
        if (!try self.isNice(line)) return;
        self.nice_count += 1;
    }

    pub fn getTotalNiceStrings(self: Text) usize {
        return self.nice_count;
    }
};

test "sample part 1" {
    {
        var text = try Text.init(std.testing.allocator, true);
        try text.addLine("ugknbfddgicrmopn");
        const visited = text.getTotalNiceStrings();
        const expected = @as(usize, 1);
        try testing.expectEqual(expected, visited);
    }
    {
        var text = try Text.init(std.testing.allocator, true);
        try text.addLine("aaa");
        const visited = text.getTotalNiceStrings();
        const expected = @as(usize, 1);
        try testing.expectEqual(expected, visited);
    }
    {
        var text = try Text.init(std.testing.allocator, true);
        try text.addLine("jchzalrnumimnmhp");
        const visited = text.getTotalNiceStrings();
        const expected = @as(usize, 0);
        try testing.expectEqual(expected, visited);
    }
    {
        var text = try Text.init(std.testing.allocator, true);
        try text.addLine("haegwjzuvuyypxyu");
        const visited = text.getTotalNiceStrings();
        const expected = @as(usize, 0);
        try testing.expectEqual(expected, visited);
    }
    {
        var text = try Text.init(std.testing.allocator, true);
        try text.addLine("dvszwmarrgswjxmb");
        const visited = text.getTotalNiceStrings();
        const expected = @as(usize, 0);
        try testing.expectEqual(expected, visited);
    }
}

test "sample part 2" {
    {
        var text = try Text.init(std.testing.allocator, false);
        try text.addLine("aabcdefeaa");
        const visited = text.getTotalNiceStrings();
        const expected = @as(usize, 1);
        try testing.expectEqual(expected, visited);
    }
    {
        var text = try Text.init(std.testing.allocator, false);
        try text.addLine("aabcdefgaa");
        const visited = text.getTotalNiceStrings();
        const expected = @as(usize, 0);
        try testing.expectEqual(expected, visited);
    }
    {
        var text = try Text.init(std.testing.allocator, false);
        try text.addLine("aaa");
        const visited = text.getTotalNiceStrings();
        const expected = @as(usize, 0);
        try testing.expectEqual(expected, visited);
    }
    {
        var text = try Text.init(std.testing.allocator, false);
        try text.addLine("aaaa");
        const visited = text.getTotalNiceStrings();
        const expected = @as(usize, 1);
        try testing.expectEqual(expected, visited);
    }
    {
        var text = try Text.init(std.testing.allocator, false);
        try text.addLine("qjhvhtzxzqqjkmpb");
        const visited = text.getTotalNiceStrings();
        const expected = @as(usize, 1);
        try testing.expectEqual(expected, visited);
    }
    {
        var text = try Text.init(std.testing.allocator, false);
        try text.addLine("xxyxx");
        const visited = text.getTotalNiceStrings();
        const expected = @as(usize, 1);
        try testing.expectEqual(expected, visited);
    }
    {
        var text = try Text.init(std.testing.allocator, false);
        try text.addLine("uurcxstgmygtbstg");
        const visited = text.getTotalNiceStrings();
        const expected = @as(usize, 0);
        try testing.expectEqual(expected, visited);
    }
    {
        var text = try Text.init(std.testing.allocator, false);
        try text.addLine("ieodomkazucvgmuy");
        const visited = text.getTotalNiceStrings();
        const expected = @as(usize, 0);
        try testing.expectEqual(expected, visited);
    }
}
