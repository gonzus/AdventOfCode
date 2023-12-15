const std = @import("std");
const testing = std.testing;

pub const Math = struct {
    pub fn gcd(a: usize, b: usize) usize {
        var va = a;
        var vb = b;
        while (vb != 0) {
            const ob = vb;
            vb = va % vb;
            va = ob;
        }
        return va;
    }

    pub fn lcm(a: usize, b: usize) usize {
        var prod: u64 = a * b;
        return prod / gcd(a, b);
    }
};
