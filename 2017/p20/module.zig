const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;
const Grid = @import("./util/grid.zig").Grid;

const Allocator = std.mem.Allocator;

pub const Simulator = struct {
    const DIM = 3;
    const ITERS = 500;
    const Vec = Math.Vector(isize, DIM);

    const Particle = struct {
        p: Vec,
        v: Vec,
        a: Vec,
        collided: bool,

        pub fn init() Particle {
            return .{ .p = undefined, .v = undefined, .a = undefined, .collided = false };
        }

        pub fn move(self: *Particle) void {
            for (0..DIM) |dim| {
                self.v.v[dim] += self.a.v[dim];
                self.p.v[dim] += self.v.v[dim];
            }
        }
    };

    allocator: Allocator,
    collisions: bool,
    particles: std.ArrayList(Particle),

    pub fn init(allocator: Allocator, collisions: bool) Simulator {
        return .{
            .allocator = allocator,
            .collisions = collisions,
            .particles = std.ArrayList(Particle).init(allocator),
        };
    }

    pub fn deinit(self: *Simulator) void {
        self.particles.deinit();
    }

    pub fn addLine(self: *Simulator, line: []const u8) !void {
        var particle = Particle.init();
        var pos: usize = 0;
        var x: isize = 0;
        var y: isize = 0;
        var z: isize = 0;
        var it = std.mem.tokenizeAny(u8, line, " =<>,");
        while (it.next()) |chunk| : (pos += 1) {
            const m = pos % 4;
            if (m == 0) continue;
            if (m == 1) x = try std.fmt.parseInt(isize, chunk, 10);
            if (m == 2) y = try std.fmt.parseInt(isize, chunk, 10);
            if (m == 3) z = try std.fmt.parseInt(isize, chunk, 10);

            if (pos == 3) {
                particle.p = Vec.copy(&[_]isize{ x, y, z });
            }
            if (pos == 7) {
                particle.v = Vec.copy(&[_]isize{ x, y, z });
            }
            if (pos == 11) {
                particle.a = Vec.copy(&[_]isize{ x, y, z });
            }
        }
        try self.particles.append(particle);
    }

    pub fn show(self: Simulator) void {
        std.debug.print("Simulator with {} particles\n", .{self.particles.items.len});
        for (self.particles.items, 0..) |particle, pos| {
            std.debug.print("{}: p={} v={} a={}\n", .{ pos, particle.p, particle.v, particle.a });
        }
    }

    pub fn findClosestToOrigin(self: *Simulator) !usize {
        try self.runUntilStable();
        const zero = Vec.init();
        var best_pos: usize = undefined;
        var best_dist: usize = std.math.maxInt(usize);
        for (self.particles.items, 0..) |particle, pos| {
            const dist = particle.p.manhattanDist(zero);
            if (best_dist > dist) {
                best_dist = dist;
                best_pos = pos;
            }
        }
        return best_pos;
    }

    pub fn countSurvivingParticles(self: *Simulator) !usize {
        try self.runUntilStable();
        var count: usize = 0;
        for (self.particles.items) |particle| {
            if (particle.collided) continue;
            count += 1;
        }
        return count;
    }

    fn runUntilStable(self: *Simulator) !void {
        var seen = std.AutoHashMap(Vec, usize).init(self.allocator);
        defer seen.deinit();

        for (0..ITERS) |_| {
            seen.clearRetainingCapacity();
            for (self.particles.items, 0..) |*particle, pos| {
                if (particle.collided) continue;

                particle.move();

                if (!self.collisions) continue;
                const r = try seen.getOrPut(particle.p);
                if (!r.found_existing) {
                    r.value_ptr.* = pos;
                } else {
                    const old = r.value_ptr.*;
                    self.particles.items[old].collided = true;
                    particle.collided = true;
                }
            }
        }
    }
};

test "sample part 1" {
    const data =
        \\p=< 3,0,0>, v=< 2,0,0>, a=<-1,0,0>
        \\p=< 4,0,0>, v=< 0,0,0>, a=<-2,0,0>
    ;

    var simulator = Simulator.init(std.testing.allocator, false);
    defer simulator.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try simulator.addLine(line);
    }
    // simulator.show();

    const particle = try simulator.findClosestToOrigin();
    const expected = @as(usize, 0);
    try testing.expectEqual(expected, particle);
}

test "sample part 2" {
    const data =
        \\p=<-6,0,0>, v=< 3,0,0>, a=< 0,0,0>
        \\p=<-4,0,0>, v=< 2,0,0>, a=< 0,0,0>
        \\p=<-2,0,0>, v=< 1,0,0>, a=< 0,0,0>
        \\p=< 3,0,0>, v=<-1,0,0>, a=< 0,0,0>
    ;

    var simulator = Simulator.init(std.testing.allocator, true);
    defer simulator.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try simulator.addLine(line);
    }
    // simulator.show();

    const particle = try simulator.countSurvivingParticles();
    const expected = @as(usize, 1);
    try testing.expectEqual(expected, particle);
}
