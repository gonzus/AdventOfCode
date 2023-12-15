const std = @import("std");
const testing = std.testing;

pub const Math = struct {
    pub fn lcm(a: usize, b: usize) usize {
        var prod: u64 = a * b;
        return prod / std.math.gcd(a, b);
    }
};

test "LCM" {
    try testing.expectEqual(Math.lcm(0, 0), 0);
    try testing.expectEqual(Math.lcm(0, 1), 0);
    try testing.expectEqual(Math.lcm(1, 0), 0);
    try testing.expectEqual(Math.lcm(1, 1), 1);
    try testing.expectEqual(Math.lcm(1, 2), 2);
    try testing.expectEqual(Math.lcm(2, 1), 2);
    try testing.expectEqual(Math.lcm(3, 6), 6);
    try testing.expectEqual(Math.lcm(4, 6), 12);
}
