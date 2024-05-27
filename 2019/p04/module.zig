const std = @import("std");

pub const Depot = struct {
    const BASE = 10;
    lo: usize,
    hi: usize,

    pub fn init() Depot {
        return .{
            .lo = 0,
            .hi = 0,
        };
    }

    pub fn addLine(self: *Depot, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, '-');
        self.lo = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        self.hi = try std.fmt.parseUnsigned(usize, it.next().?, 10);
    }

    pub fn getPasswordCount(self: *Depot, strict: bool) usize {
        var count: usize = 0;
        for (self.lo..self.hi + 1) |number| {
            const matched = matchTwoOnly(number, strict);
            if (!matched) continue;
            count += 1;
        }
        return count;
    }

    fn matchTwoOnly(number: usize, strict: bool) bool {
        var digit_count: [BASE]usize = [_]usize{0} ** BASE;
        var copy = number;
        var previous: usize = BASE;
        while (copy > 0) {
            const digit = copy % BASE;
            copy /= BASE;
            if (digit > previous) {
                return false;
            }
            if (digit == previous) {
                digit_count[digit] += 1;
            }
            previous = digit;
        }
        var sum: usize = 0;
        for (0..BASE) |j| {
            if (!strict or digit_count[j] == 1) {
                sum += digit_count[j];
            }
        }
        return (sum > 0);
    }
};
