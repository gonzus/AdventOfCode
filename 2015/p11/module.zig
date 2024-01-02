const std = @import("std");
const testing = std.testing;

pub const Password = struct {
    text: [8]u8,

    pub fn init() Password {
        return Password{ .text = undefined };
    }

    pub fn addLine(self: *Password, line: []const u8) !void {
        if (line.len != self.text.len) unreachable;
        std.mem.copyForwards(u8, &self.text, line);
    }

    pub fn findNext(self: *Password) ![]const u8 {
        while (true) {
            try self.increment();
            if (self.isValid()) break;
        }
        return &self.text;
    }

    fn isValid(self: Password) bool {
        var c1: u8 = 0;
        var c2: u8 = 0;
        var scales: usize = 0;
        var doubles: usize = 0;
        for (self.text) |c0| {
            if (c0 == 'i' or c0 == 'o' or c0 == 'l') return false;
            if (c0 == c1 + 1 and c1 == c2 + 1) {
                scales += 1;
            }
            if (c0 == c1 and c1 != c2) {
                doubles += 1;
            }
            c2 = c1;
            c1 = c0;
        }
        if (doubles < 2) return false;
        if (scales < 1) return false;
        return true;
    }

    fn increment(self: *Password) !void {
        for (self.text, 0..) |_, n| {
            const p = self.text.len - n - 1;
            if (self.text[p] != 'z') {
                self.text[p] += 1;
                return;
            }
            self.text[p] = 'a';
        }
        unreachable;
    }
};

test "sample part 1" {
    {
        var password = Password.init();
        try password.addLine("hijklmmn");
        try testing.expect(!password.isValid());
    }
    {
        var password = Password.init();
        try password.addLine("abbceffg");
        try testing.expect(!password.isValid());
    }
    {
        var password = Password.init();
        try password.addLine("abbcegjk");
        try testing.expect(!password.isValid());
    }
    {
        var password = Password.init();
        try password.addLine("abcdefgh");
        const next = try password.findNext();
        try testing.expectEqualSlices(u8, "abcdffaa", next);
    }
    {
        var password = Password.init();
        try password.addLine("ghijklmn");
        const next = try password.findNext();
        try testing.expectEqualSlices(u8, "ghjaabcc", next);
    }
}
