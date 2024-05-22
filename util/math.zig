const std = @import("std");
const testing = std.testing;

pub const Math = struct {
    pub const INFINITY = std.math.maxInt(usize);

    pub fn lcm(a: usize, b: usize) usize {
        const prod: u64 = a * b;
        return prod / std.math.gcd(a, b);
    }

    // TODO: implement a proper sieve
    pub fn isPrime(n: usize) bool {
        if (n <= 1) return false;
        if (n == 2) return true;
        if (n % 2 == 0) return false;
        var f: usize = 3;
        while (f * f <= n) : (f += 2) {
            if (n % f == 0) return false;
        }
        return true;
    }

    // given equations: X = divs[j] (mod mods[j])
    // compute a value for X
    pub fn chineseRemainder(divs: []const u64, mods: []const u64) u64 {
        if (divs.len != mods.len) return 0;

        const len = divs.len;
        if (len == 0) return 0;

        var prod: u64 = 1;
        for (0..len) |k| {
            // if this overflows, can't do
            prod *= divs[k];
        }

        var sum: u64 = 0;
        for (0..len) |k| {
            const n: u64 = prod / divs[k];
            sum += mods[k] * mulInverse(n, divs[k]) * n;
        }

        return sum % prod;
    }

    // returns X where (a * X) % b == 1
    fn mulInverse(a: u64, b: u64) u64 {
        if (b == 1) return 1;

        var va: i64 = @intCast(a);
        var vb: i64 = @intCast(b);
        var x0: i64 = 0;
        var x1: i64 = 1;
        while (va > 1) {
            const q = @divTrunc(va, vb);
            {
                // both @mod and @rem work here
                const t = vb;
                vb = @mod(va, vb);
                va = t;
            }
            {
                const t = x0;
                x0 = x1 - q * x0;
                x1 = t;
            }
        }
        while (x1 < 0) {
            x1 += @intCast(b);
        }
        return @intCast(x1);
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
                _ = try writer.print("V", .{});
                for (0..size) |p| {
                    const c: u8 = if (p == 0) '(' else ',';
                    _ = try writer.print("{c}{d}", .{ c, v.v[p] });
                }
                _ = try writer.print(")", .{});
            }

            v: [S]T,
        };
    }

    pub const Pos2D = Vector(usize, 2);

    pub const Rectangle = struct {
        tl: Pos2D,
        br: Pos2D,

        pub fn initTLBR(t: usize, l: usize, b: usize, r: usize) Rectangle {
            return .{
                .tl = Pos2D.copy(&[_]usize{ l, t }),
                .br = Pos2D.copy(&[_]usize{ r, b }),
            };
        }

        pub fn initTLWH(t: usize, l: usize, w: usize, h: usize) Rectangle {
            return Rectangle.initTLBR(t, l, t + h - 1, l + w - 1);
        }

        pub fn format(
            v: Rectangle,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("Rect({}-{})", .{ v.tl, v.br });
        }

        pub fn getOverlap(self: Rectangle, other: Rectangle) Rectangle {
            return Rectangle.initTLBR(
                @max(self.tl.v[1], other.tl.v[1]),
                @max(self.tl.v[0], other.tl.v[0]),
                @min(self.br.v[1], other.br.v[1]),
                @min(self.br.v[0], other.br.v[0]),
            );
        }

        pub fn isValid(self: Rectangle) bool {
            return self.tl.v[1] <= self.br.v[1] and self.tl.v[0] <= self.br.v[0];
        }
    };
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

test "isPrime" {
    var primes = [_]usize{ 2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97 };
    for (0..100) |n| {
        var found = false;
        for (&primes) |p| {
            if (n == p) {
                found = true;
                break;
            }
        }
        try testing.expectEqual(Math.isPrime(n), found);
    }
}

test "chinese reminder" {
    {
        const divs = [_]usize{ 3, 5, 7 };
        const mods = [_]usize{ 2, 3, 2 };
        const cr = Math.chineseRemainder(divs[0..], mods[0..]);
        try testing.expectEqual(@as(usize, 23), cr);
    }
    {
        const divs = [_]usize{ 3, 4, 5 };
        const mods = [_]usize{ 1, 2, 4 };
        const cr = Math.chineseRemainder(divs[0..], mods[0..]);
        try testing.expectEqual(@as(usize, 34), cr);
    }
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
