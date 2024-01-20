const std = @import("std");
const testing = std.testing;

pub const Door = struct {
    const PASSWORD_LENGTH = 8;

    simple: bool,
    door_buf: [100]u8,
    door_len: usize,

    pub fn init(simple: bool) Door {
        return Door{ .simple = simple, .door_buf = undefined, .door_len = 0 };
    }

    pub fn addLine(self: *Door, line: []const u8) !void {
        std.mem.copyForwards(u8, &self.door_buf, line);
        self.door_len = line.len;
    }

    pub fn findPassword(self: Door, buffer: []u8) ![]const u8 {
        for (buffer) |*b| {
            b.* = 0;
        }
        const door = self.door_buf[0..self.door_len];
        var found: usize = 0;
        var val: usize = 0;
        var buf: [100]u8 = undefined;
        std.mem.copyForwards(u8, &buf, door);
        while (found < PASSWORD_LENGTH) : (val += 1) {
            const num = try std.fmt.bufPrint(buf[door.len..], "{d}", .{val});
            const txt = buf[0 .. door.len + num.len];
            var hash: [std.crypto.hash.Md5.digest_length]u8 = undefined;
            std.crypto.hash.Md5.hash(txt, &hash, .{});
            if (hash[0] > 0x0) continue;
            if (hash[1] > 0x0) continue;
            if (hash[2] > 0xf) continue;

            var pos: usize = found;
            var digit: u8 = 0;
            if (self.simple) {
                digit = try getDigit(hash[2] & 0xf);
            } else {
                pos = hash[2] & 0xf;
                if (pos < PASSWORD_LENGTH and buffer[pos] == 0) {
                    digit = try getDigit(hash[3] >> 0x4);
                }
            }
            if (digit == 0) continue;
            buffer[pos] = digit;
            found += 1;
        }
        return buffer[0..found];
    }

    fn getDigit(nibble: u8) !u8 {
        return switch (nibble) {
            0...9 => |d| d - 0 + '0',
            10...15 => |d| d - 10 + 'a',
            else => return error.InvalidNibble,
        };
    }
};

test "sample part 1" {
    const data =
        \\abc
    ;

    var door = Door.init(true);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try door.addLine(line);
    }

    var buf: [100]u8 = undefined;
    const password = try door.findPassword(&buf);
    const expected = "18f47a30";
    try testing.expectEqualSlices(u8, expected, password);
}

test "sample part 2" {
    const data =
        \\abc
    ;

    var door = Door.init(false);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try door.addLine(line);
    }

    var buf: [100]u8 = undefined;
    const password = try door.findPassword(&buf);
    const expected = "05ace8e3";
    try testing.expectEqualSlices(u8, expected, password);
}
