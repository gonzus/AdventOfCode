const std = @import("std");
const testing = std.testing;

pub const Coin = struct {
    const MAX_ITERATIONS = 5_000_000;

    key: []const u8,

    pub fn init() !Coin {
        const self = Coin{ .key = undefined };
        return self;
    }

    pub fn addLine(self: *Coin, line: []const u8) !void {
        self.key = line;
    }

    pub fn findFirstHashWithZeroes(self: Coin, num_zeroes: usize) !usize {
        const half = @divTrunc(num_zeroes, 2);
        const twice = 2 * half;
        var number: usize = 1;
        while (number < 5_000_000) : (number += 1) {
            var buffer: [100]u8 = undefined;
            const str = try std.fmt.bufPrint(&buffer, "{s}{d}", .{ self.key, number });
            var hash: [std.crypto.hash.Md5.digest_length]u8 = undefined;
            std.crypto.hash.Md5.hash(str, &hash, .{});
            for (hash, 0..) |b, p| {
                if (p >= half) {
                    if (twice == num_zeroes) return number;
                    if (b <= 0x0f) return number;
                }
                if (b != 0) break;
            }
        }
        return 0;
    }
};

test "sample part 1" {
    var coin = try Coin.init();

    {
        try coin.addLine("abcdef");
        const number = try coin.findFirstHashWithZeroes(5);
        const expected = @as(usize, 609043);
        try testing.expectEqual(expected, number);
    }
    {
        try coin.addLine("pqrstuv");
        const number = try coin.findFirstHashWithZeroes(5);
        const expected = @as(usize, 1048970);
        try testing.expectEqual(expected, number);
    }
}
