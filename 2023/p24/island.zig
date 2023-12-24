const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Air = struct {
    pub const V3 = Math.Vector(isize, 3);

    const Hailstone = struct {
        pos: V3,
        vel: V3,

        pub fn init(pos: V3, vel: V3) Hailstone {
            return Hailstone{
                .pos = pos,
                .vel = vel,
            };
        }

        pub fn lessThan(_: void, l: Hailstone, r: Hailstone) bool {
            return V3.lessThan({}, l.pos, r.pos);
        }
    };

    allocator: Allocator,
    hailstones: std.ArrayList(Hailstone),
    pending: std.ArrayList(isize),

    pub fn init(allocator: Allocator) Air {
        var self = Air{
            .allocator = allocator,
            .hailstones = std.ArrayList(Hailstone).init(allocator),
            .pending = std.ArrayList(isize).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Air) void {
        self.pending.deinit();
        self.hailstones.deinit();
    }

    pub fn addLine(self: *Air, line: []const u8) !void {
        var pos: V3 = undefined;
        var vel: V3 = undefined;
        var hailstone_count: usize = 0;
        var it_hailstone = std.mem.tokenizeSequence(u8, line, " @ ");
        while (it_hailstone.next()) |hailstone_chunk| : (hailstone_count += 1) {
            var coord_cnt: usize = 0;
            var it_coord = std.mem.tokenizeAny(u8, hailstone_chunk, " ,");
            while (it_coord.next()) |str| : (coord_cnt += 1) {
                const n = try std.fmt.parseInt(isize, str, 10);
                switch (hailstone_count) {
                    0 => switch (coord_cnt) {
                        0...2 => |i| pos.v[i] = n,
                        else => unreachable,
                    },
                    1 => switch (coord_cnt) {
                        0...2 => |i| vel.v[i] = n,
                        else => unreachable,
                    },
                    else => unreachable,
                }
            }
        }
        const hailstone = Hailstone.init(pos, vel);
        try self.hailstones.append(hailstone);
    }

    pub fn getIntersectingHailstonesInArea(self: *Air, min: isize, max: isize) !usize {
        const size = self.hailstones.items.len;
        var count: usize = 0;
        for (0..size) |pl| {
            const hl = self.hailstones.items[pl];
            const pxa = hl.pos.v[0];
            const pya = hl.pos.v[1];
            const vxa = hl.vel.v[0];
            const vya = hl.vel.v[1];
            const ma = getLineM(vxa, vya, 0, 0);
            const na = getLineN(pxa, pya, ma);
            for (pl + 1..size) |pr| {
                const hr = self.hailstones.items[pr];
                const pxb = hr.pos.v[0];
                const pyb = hr.pos.v[1];
                const vxb = hr.vel.v[0];
                const vyb = hr.vel.v[1];
                const mb = getLineM(vxb, vyb, 0, 0);
                const nb = getLineN(pxb, pyb, mb);

                if (ma == mb) continue;

                const xf = (nb - na) / (ma - mb);
                const yf = ma * xf + na;
                const x: isize = @intFromFloat(xf);
                const y: isize = @intFromFloat(yf);

                if (x < pxa and vxa > 0) continue;
                if (x > pxa and vxa < 0) continue;
                if (x < pxb and vxb > 0) continue;
                if (x > pxb and vxb < 0) continue;

                if (x < min or x > max) continue;
                if (y < min or y > max) continue;

                count += 1;
            }
        }
        return count;
    }

    pub fn findSumPosHittingRock(self: *Air) !usize {
        const size = self.hailstones.items.len;
        var set_x = Set.init(self.allocator);
        defer set_x.deinit();
        var set_y = Set.init(self.allocator);
        defer set_y.deinit();
        var set_z = Set.init(self.allocator);
        defer set_z.deinit();
        std.sort.heap(Hailstone, self.hailstones.items, {}, Hailstone.lessThan);
        for (0..size) |pl| {
            const hl = self.hailstones.items[pl];
            const pxa = hl.pos.v[0];
            const pya = hl.pos.v[1];
            const pza = hl.pos.v[2];
            const vxa = hl.vel.v[0];
            const vya = hl.vel.v[1];
            const vza = hl.vel.v[2];
            for (pl + 1..size) |pr| {
                const hr = self.hailstones.items[pr];
                const pxb = hr.pos.v[0];
                const pyb = hr.pos.v[1];
                const pzb = hr.pos.v[2];
                const vxb = hr.vel.v[0];
                const vyb = hr.vel.v[1];
                const vzb = hr.vel.v[2];
                if (vxa == vxb) {
                    try self.potential(pxa, pxb, vxa, &set_x);
                }
                if (vya == vyb) {
                    try self.potential(pya, pyb, vya, &set_y);
                }
                if (vza == vzb) {
                    try self.potential(pza, pzb, vza, &set_z);
                }
            }
        }

        // We assume here each set ended up with a unique element
        const vx = try getUniqueElement(set_x);
        const vy = try getUniqueElement(set_y);
        const vz = try getUniqueElement(set_z);

        const h0 = self.hailstones.items[0];
        const pxa = h0.pos.v[0];
        const pya = h0.pos.v[1];
        const pza = h0.pos.v[2];
        const vxa = h0.vel.v[0];
        const vya = h0.vel.v[1];
        const vza = h0.vel.v[2];
        const h1 = self.hailstones.items[1];
        const pxb = h1.pos.v[0];
        const pyb = h1.pos.v[1];
        const vxb = h1.vel.v[0];
        const vyb = h1.vel.v[1];
        const ma = getLineM(vxa, vya, vx, vy);
        const mb = getLineM(vxb, vyb, vx, vy);
        const na = getLineN(pxa, pya, ma);
        const nb = getLineN(pxb, pyb, mb);
        const xf = (nb - na) / (ma - mb);
        const yf = ma * xf + na;
        const x: isize = @intFromFloat(xf);
        const y: isize = @intFromFloat(yf);
        const apxf: f64 = @floatFromInt(pxa);
        const avxf: f64 = @floatFromInt(vxa);
        const rvxf: f64 = @floatFromInt(vx);
        const tf = (xf - apxf) / (avxf - rvxf);
        const t: isize = @intFromFloat(tf);
        const z: isize = pza + (vza - vz) * t;

        const sum: isize = x + y + z;
        return @intCast(sum);
    }

    const Set = std.AutoHashMap(isize, void);

    fn potential(self: *Air, pa: isize, pb: isize, va: isize, set: *Set) !void {
        const empty = set.count() == 0;
        self.pending.clearRetainingCapacity();
        const delta = pb - pa;
        var v: isize = -1000;
        while (v <= 1000) : (v += 1) {
            if (v == va) continue;
            const m = @mod(delta, v - va);
            if (m != 0) continue;
            if (empty or set.*.contains(v)) {
                try self.pending.append(v);
            }
        }
        set.*.clearRetainingCapacity();
        for (self.pending.items) |p| {
            try set.*.put(p, {});
        }
    }

    fn getUniqueElement(set: Set) !isize {
        var it = set.keyIterator();
        var elem: isize = undefined;
        var count: usize = 0;
        while (it.next()) |k| {
            elem = k.*;
            count += 1;
        }
        if (count != 1) return error.NoUniqueElement;
        return elem;
    }

    fn getLineM(xa: isize, ya: isize, xb: isize, yb: isize) f64 {
        const dx = xa - xb;
        const dy = ya - yb;
        const x: f64 = @floatFromInt(dx);
        const y: f64 = @floatFromInt(dy);
        return y / x;
    }

    fn getLineN(px: isize, py: isize, M: f64) f64 {
        const x: f64 = @floatFromInt(px);
        const y: f64 = @floatFromInt(py);
        return y - (M * x);
    }
};

test "sample simple part 1" {
    const data =
        \\19, 13, 30 @ -2,  1, -2
        \\18, 19, 22 @ -1, -1, -2
        \\20, 25, 34 @ -2, -2, -4
        \\12, 31, 28 @ -1, -2, -1
        \\20, 19, 15 @  1, -5, -3
    ;

    var air = Air.init(std.testing.allocator);
    defer air.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try air.addLine(line);
    }

    const count = try air.getIntersectingHailstonesInArea(7, 27);
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, count);
}

test "sample simple part 2" {
    const data =
        \\19, 13, 30 @ -2,  1, -2
        \\18, 19, 22 @ -1, -1, -2
        \\20, 25, 34 @ -2, -2, -4
        \\12, 31, 28 @ -1, -2, -1
        \\20, 19, 15 @  1, -5, -3
    ;
    std.debug.print("\n", .{});

    var air = Air.init(std.testing.allocator);
    defer air.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try air.addLine(line);
    }

    const count = try air.findSumPosHittingRock();
    const expected = @as(usize, 47);
    try testing.expectEqual(expected, count);
}
