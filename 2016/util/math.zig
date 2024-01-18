const std = @import("std");
const testing = std.testing;

pub const Math = struct {
    pub fn lcm(a: usize, b: usize) usize {
        const prod: u64 = a * b;
        return prod / std.math.gcd(a, b);
    }

    pub fn Vector(comptime T: type, comptime S: usize) type {
        return struct {
            const Self = @This();
            const size = S;

            pub fn init() Self {
                var self = Self{ .v = undefined };
                for (0..size) |p| {
                    self.v[p] = 0;
                }
                return self;
            }

            pub fn unit(dim: usize) Self {
                var self = Self{ .v = undefined };
                for (0..size) |p| {
                    self.v[p] = if (p == dim) 1 else 0;
                }
                return self;
            }

            pub fn copy(data: []const T) Self {
                var self = Self{ .v = undefined };
                var top: usize = self.v.len;
                if (top > data.len) top = data.len;
                for (0..top) |p| {
                    self.v[p] = data[p];
                }
                return self;
            }

            pub fn add(l: Self, r: Self) Self {
                var self = Self{ .v = undefined };
                for (0..size) |p| {
                    self.v[p] = l.v[p] + r.v[p];
                }
                return self;
            }

            pub fn sub(l: Self, r: Self) Self {
                var self = Self{ .v = undefined };
                for (0..size) |p| {
                    self.v[p] = l.v[p] - r.v[p];
                }
                return self;
            }

            pub fn manhattanDist(l: Self, r: Self) usize {
                var dist: usize = 0;
                for (0..size) |p| {
                    const d = if (l.v[p] < r.v[p]) r.v[p] - l.v[p] else l.v[p] - r.v[p];
                    const u: usize = @intCast(d);
                    dist += u;
                }
                return dist;
            }

            pub fn euclideanDistSq(l: Self, r: Self) usize {
                var dist: usize = 0;
                for (0..size) |p| {
                    const d = if (l.v[p] < r.v[p]) r.v[p] - l.v[p] else l.v[p] - r.v[p];
                    const u: usize = @intCast(d);
                    dist += u * u;
                }
                return dist;
            }

            pub fn cmp(_: void, l: Self, r: Self) std.math.Order {
                for (0..size) |n| {
                    const p = size - n - 1;
                    if (l.v[p] < r.v[p]) return std.math.Order.lt;
                    if (l.v[p] > r.v[p]) return std.math.Order.gt;
                }
                return std.math.Order.eq;
            }

            pub fn equal(l: Self, r: Self) bool {
                return Self.cmp({}, l, r) == std.math.Order.eq;
            }

            pub fn lessThan(_: void, l: Self, r: Self) bool {
                return Self.cmp({}, l, r) == std.math.Order.lt;
            }

            pub fn format(
                v: Self,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                for (0..size) |p| {
                    const c: u8 = if (p == 0) '(' else ',';
                    _ = try writer.print("{c}{d}", .{ c, v.v[p] });
                }
                _ = try writer.print(")", .{});
            }

            v: [S]T,
        };
    }
};

test "LCM" {
    try testing.expectEqual(Math.lcm(0, 1), 0);
    try testing.expectEqual(Math.lcm(1, 0), 0);
    try testing.expectEqual(Math.lcm(1, 1), 1);
    try testing.expectEqual(Math.lcm(1, 2), 2);
    try testing.expectEqual(Math.lcm(2, 1), 2);
    try testing.expectEqual(Math.lcm(3, 6), 6);
    try testing.expectEqual(Math.lcm(4, 6), 12);
}

test "V2" {
    const V2 = Math.Vector(isize, 2);
    const p1 = V2.copy(&[_]isize{ 3, 5 });
    const p2 = V2.copy(&[_]isize{ 2, 8 });
    try testing.expect(V2.equal(p1, p1));
    try testing.expect(V2.equal(p2, p2));
    try testing.expect(!V2.equal(p1, p2));
    try testing.expect(!V2.equal(p2, p1));
    try testing.expect(p1.equal(p1));
    try testing.expect(p2.equal(p2));
    try testing.expect(!p1.equal(p2));
    try testing.expect(!p2.equal(p1));
    try testing.expectEqual(p1.manhattanDist(p2), 4);
    try testing.expectEqual(p1.euclideanDistSq(p2), 10);
    try testing.expectEqual(V2.cmp({}, p1, p2), std.math.Order.lt);
    try testing.expectEqual(V2.cmp({}, p2, p1), std.math.Order.gt);
    try testing.expectEqual(V2.cmp({}, p1, p1), std.math.Order.eq);
    try testing.expectEqual(V2.cmp({}, p2, p2), std.math.Order.eq);
    try testing.expect(V2.lessThan({}, p1, p2));
    try testing.expect(!V2.lessThan({}, p2, p1));
}
