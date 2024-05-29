const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub const Map = struct {
    const DIM = 3;
    const OFFSET = 10000;
    const Vec = Math.Vector(i32, DIM);

    const Moon = struct {
        pos: Vec,
        vel: Vec,

        pub fn init(x: i32, y: i32, z: i32) Moon {
            return .{
                .pos = Vec.copy(&[_]i32{ x, y, z }),
                .vel = Vec.init(),
            };
        }
    };

    pub const Trace = struct {
        data: std.AutoHashMap(u128, void),
        done: bool,

        pub fn init(allocator: Allocator) Trace {
            return .{
                .data = std.AutoHashMap(u128, void).init(allocator),
                .done = false,
            };
        }

        pub fn deinit(self: *Trace) void {
            self.data.deinit();
        }
    };

    moons: std.ArrayList(Moon),
    trace: [DIM]Trace,

    pub fn init(allocator: Allocator) Map {
        var self = Map{
            .moons = std.ArrayList(Moon).init(allocator),
            .trace = undefined,
        };
        for (0..DIM) |dim| {
            self.trace[dim] = Trace.init(allocator);
        }
        return self;
    }

    pub fn deinit(self: *Map) void {
        for (0..DIM) |dim| {
            self.trace[dim].deinit();
        }
        self.moons.deinit();
    }

    pub fn addLine(self: *Map, line: []const u8) !void {
        var it = std.mem.tokenizeAny(u8, line, " <>,=");

        assert(std.mem.eql(u8, it.next().?, "x"));
        const x = try std.fmt.parseInt(i32, it.next().?, 10);
        assert(std.mem.eql(u8, it.next().?, "y"));
        const y = try std.fmt.parseInt(i32, it.next().?, 10);
        assert(std.mem.eql(u8, it.next().?, "z"));
        const z = try std.fmt.parseInt(i32, it.next().?, 10);

        try self.moons.append(Moon.init(x, y, z));
    }

    pub fn getEnergyAfterSteps(self: *Map, steps: usize) !usize {
        for (0..steps) |_| {
            try self.step();
        }
        return self.getTotalEnergy();
    }

    pub fn getFinalCycleSize(self: *Map) !usize {
        while (!self.isTraceCompleted()) {
            try self.step();
        }
        return self.getCycleSize();
    }

    fn step(self: *Map) !void {
        for (0..DIM) |dim| {
            if (self.trace[dim].done) continue;
            try self.traceStep(dim);
        }
        const moons = self.moons.items;

        for (0..moons.len) |j| {
            for (j + 1..moons.len) |k| {
                for (0..DIM) |dim| {
                    if (moons[j].pos.v[dim] < moons[k].pos.v[dim]) {
                        moons[j].vel.v[dim] += 1;
                        moons[k].vel.v[dim] -= 1;
                        continue;
                    }
                    if (moons[j].pos.v[dim] > moons[k].pos.v[dim]) {
                        moons[j].vel.v[dim] -= 1;
                        moons[k].vel.v[dim] += 1;
                        continue;
                    }
                }
            }
        }

        for (0..moons.len) |j| {
            for (0..DIM) |dim| {
                moons[j].pos.v[dim] += moons[j].vel.v[dim];
            }
        }
    }

    fn getTotalEnergy(self: Map) usize {
        var energy: usize = 0;
        const moons = self.moons.items;
        for (0..moons.len) |j| {
            var pot: usize = 0;
            var kin: usize = 0;
            for (0..DIM) |dim| {
                pot += @abs(moons[j].pos.v[dim]);
                kin += @abs(moons[j].vel.v[dim]);
            }
            energy += pot * kin;
        }
        return energy;
    }

    fn isTraceCompleted(self: *Map) bool {
        for (0..DIM) |dim| {
            if (!self.trace[dim].done) return false;
        }
        return true;
    }

    fn traceStep(self: *Map, dim: usize) !void {
        var label: u128 = 0;
        const moons = self.moons.items;
        for (0..moons.len) |j| {
            label *= OFFSET;
            label += @intCast(OFFSET - moons[j].pos.v[dim]);
            label *= OFFSET;
            label += @intCast(OFFSET - moons[j].vel.v[dim]);
        }
        const r = try self.trace[dim].data.getOrPut(label);
        if (r.found_existing) {
            self.trace[dim].done = true;
        }
    }

    fn getCycleSize(self: Map) usize {
        var size: usize = 1;
        for (0..DIM) |dim| {
            const count = self.trace[dim].data.count();
            if (dim == 0) {
                size = count;
                continue;
            }
            const gcd = std.math.gcd(count, size);
            size *= count / gcd;
        }
        return size;
    }
};

test "energy aftr 10 steps" {
    const data: []const u8 =
        \\<x=-1, y=0, z=2>
        \\<x=2, y=-10, z=-7>
        \\<x=4, y=-8, z=8>
        \\<x=3, y=5, z=-1>
    ;
    var map = Map.init(testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }

    {
        const energy = map.getEnergyAfterSteps(10);
        const expected = @as(usize, 179);
        try testing.expectEqual(expected, energy);

        const moons = map.moons.items;
        assert(moons[0].pos.v[0] == 2);
        assert(moons[0].pos.v[1] == 1);
        assert(moons[0].pos.v[2] == -3);
        assert(moons[0].vel.v[0] == -3);
        assert(moons[0].vel.v[1] == -2);
        assert(moons[0].vel.v[2] == 1);
        assert(moons[1].pos.v[0] == 1);
        assert(moons[1].pos.v[1] == -8);
        assert(moons[1].pos.v[2] == 0);
        assert(moons[1].vel.v[0] == -1);
        assert(moons[1].vel.v[1] == 1);
        assert(moons[1].vel.v[2] == 3);
        assert(moons[2].pos.v[0] == 3);
        assert(moons[2].pos.v[1] == -6);
        assert(moons[2].pos.v[2] == 1);
        assert(moons[2].vel.v[0] == 3);
        assert(moons[2].vel.v[1] == 2);
        assert(moons[2].vel.v[2] == -3);
        assert(moons[3].pos.v[0] == 2);
        assert(moons[3].pos.v[1] == 0);
        assert(moons[3].pos.v[2] == 4);
        assert(moons[3].vel.v[0] == 1);
        assert(moons[3].vel.v[1] == -1);
        assert(moons[3].vel.v[2] == -1);
    }
}

test "energy aftr 100 steps" {
    const data: []const u8 =
        \\<x=-8, y=-10, z=0>
        \\<x=5, y=5, z=10>
        \\<x=2, y=-7, z=3>
        \\<x=9, y=-8, z=-3>
    ;
    var map = Map.init(testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }

    {
        const energy = map.getEnergyAfterSteps(100);
        const expected = @as(usize, 1940);
        try testing.expectEqual(expected, energy);

        const moons = map.moons.items;
        assert(moons[0].pos.v[0] == 8);
        assert(moons[0].pos.v[1] == -12);
        assert(moons[0].pos.v[2] == -9);
        assert(moons[0].vel.v[0] == -7);
        assert(moons[0].vel.v[1] == 3);
        assert(moons[0].vel.v[2] == 0);
        assert(moons[1].pos.v[0] == 13);
        assert(moons[1].pos.v[1] == 16);
        assert(moons[1].pos.v[2] == -3);
        assert(moons[1].vel.v[0] == 3);
        assert(moons[1].vel.v[1] == -11);
        assert(moons[1].vel.v[2] == -5);
        assert(moons[2].pos.v[0] == -29);
        assert(moons[2].pos.v[1] == -11);
        assert(moons[2].pos.v[2] == -1);
        assert(moons[2].vel.v[0] == -3);
        assert(moons[2].vel.v[1] == 7);
        assert(moons[2].vel.v[2] == 4);
        assert(moons[3].pos.v[0] == 16);
        assert(moons[3].pos.v[1] == -13);
        assert(moons[3].pos.v[2] == 23);
        assert(moons[3].vel.v[0] == 7);
        assert(moons[3].vel.v[1] == 1);
        assert(moons[3].vel.v[2] == 1);
    }
}

test "cycle size small" {
    const data: []const u8 =
        \\<x=-1, y=0, z=2>
        \\<x=2, y=-10, z=-7>
        \\<x=4, y=-8, z=8>
        \\<x=3, y=5, z=-1>
    ;
    var map = Map.init(testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }

    {
        const energy = map.getEnergyAfterSteps(2772);
        const expected = @as(usize, 0);
        try testing.expectEqual(expected, energy);

        const moons = map.moons.items;
        assert(moons[0].pos.v[0] == -1);
        assert(moons[0].pos.v[1] == 0);
        assert(moons[0].pos.v[2] == 2);
        assert(moons[0].vel.v[0] == 0);
        assert(moons[0].vel.v[1] == 0);
        assert(moons[0].vel.v[2] == 0);
        assert(moons[1].pos.v[0] == 2);
        assert(moons[1].pos.v[1] == -10);
        assert(moons[1].pos.v[2] == -7);
        assert(moons[1].vel.v[0] == 0);
        assert(moons[1].vel.v[1] == 0);
        assert(moons[1].vel.v[2] == 0);
        assert(moons[2].pos.v[0] == 4);
        assert(moons[2].pos.v[1] == -8);
        assert(moons[2].pos.v[2] == 8);
        assert(moons[2].vel.v[0] == 0);
        assert(moons[2].vel.v[1] == 0);
        assert(moons[2].vel.v[2] == 0);
        assert(moons[3].pos.v[0] == 3);
        assert(moons[3].pos.v[1] == 5);
        assert(moons[3].pos.v[2] == -1);
        assert(moons[3].vel.v[0] == 0);
        assert(moons[3].vel.v[1] == 0);
        assert(moons[3].vel.v[2] == 0);
    }

    {
        const size = map.getCycleSize();
        const expected = @as(usize, 2772);
        try testing.expectEqual(expected, size);
    }
}

test "cycle size large" {
    const data: []const u8 =
        \\<x=-8, y=-10, z=0>
        \\<x=5, y=5, z=10>
        \\<x=2, y=-7, z=3>
        \\<x=9, y=-8, z=-3>
    ;
    var map = Map.init(testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }

    {
        const size = try map.getFinalCycleSize();
        const expected = @as(usize, 4686774924);
        try testing.expectEqual(expected, size);
    }
}
