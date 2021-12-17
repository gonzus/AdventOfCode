const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const Probe = struct {
    const V2 = struct {
        x: isize,
        y: isize,

        pub fn init(x: isize, y: isize) V2 {
            var self = V2{ .x = x, .y = y };
            return self;
        }
    };

    tmin: V2,
    tmax: V2,

    pub fn init() Probe {
        var self = Probe{
            .tmin = V2.init(0, 0),
            .tmax = V2.init(0, 0),
        };
        return self;
    }

    pub fn deinit(_: *Probe) void {}

    pub fn process_line(self: *Probe, data: []const u8) !void {
        var pos_colon: usize = 0;
        var it_colon = std.mem.split(u8, data, ":");
        while (it_colon.next()) |data_colon| : (pos_colon += 1) {
            if (pos_colon != 1) continue;
            var pos_comma: usize = 0;
            var it_comma = std.mem.split(u8, data_colon, ",");
            while (it_comma.next()) |data_comma| : (pos_comma += 1) {
                var pos_eq: usize = 0;
                var it_eq = std.mem.split(u8, data_comma, "=");
                while (it_eq.next()) |data_eq| : (pos_eq += 1) {
                    if (pos_eq != 1) continue;
                    var pos_dots: usize = 0;
                    var it_dots = std.mem.split(u8, data_eq, "..");
                    while (it_dots.next()) |num| : (pos_dots += 1) {
                        const n = std.fmt.parseInt(isize, num, 10) catch unreachable;
                        if (pos_comma == 0 and pos_dots == 0) {
                            self.tmin.x = n;
                            continue;
                        }
                        if (pos_comma == 0 and pos_dots == 1) {
                            self.tmax.x = n;
                            continue;
                        }
                        if (pos_comma == 1 and pos_dots == 0) {
                            self.tmin.y = n;
                            continue;
                        }
                        if (pos_comma == 1 and pos_dots == 1) {
                            self.tmax.y = n;
                            continue;
                        }
                        unreachable;
                    }
                }
            }
            // std.debug.warn("LINE => {} {}\n", .{ self.tmin, self.tmax });
        }
    }

    pub fn shoot(self: Probe, vel_ini: V2) isize {
        var pos: V2 = V2.init(0, 0);
        var vel: V2 = vel_ini;
        var top: isize = 0;
        while (true) {
            if (pos.x >= self.tmin.x and pos.x <= self.tmax.x and pos.y >= self.tmin.y and pos.y <= self.tmax.y) {
                return top;
            }

            if (vel.x == 0 and pos.x < self.tmin.x and pos.x > self.tmax.x) break;
            if (vel.y < 0 and pos.y < self.tmin.y) break;

            pos.y += vel.y;
            pos.x += vel.x;
            vel.y -= 1;
            if (vel.x > 0) {
                vel.x -= 1;
            } else if (vel.x < 0) {
                vel.x += 1;
            }
            if (top < pos.y) top = pos.y;
        }
        return std.math.minInt(isize);
    }

    fn get_vx(x: isize) isize {
        const ux = @intCast(usize, std.math.absInt(x) catch unreachable);
        const delta = 1 + 8 * ux;
        const vx = @divTrunc(@intCast(isize, std.math.sqrt(delta)), 2);
        return vx;
    }

    pub fn find_highest_position(self: Probe) isize {
        const mx = @divTrunc(self.tmax.x + self.tmin.x, 2);
        const vx = get_vx(mx);

        // we can find vx deterministically, but vy is brute-forced... :-(
        var vel = V2.init(vx, 0);
        var highest_pos: isize = std.math.minInt(isize);
        var vy: isize = -200;
        while (vy <= 200) : (vy += 1) {
            vel.y = vy;
            const h = self.shoot(vel);
            if (highest_pos < h) highest_pos = h;
        }
        return highest_pos;
    }

    pub fn count_velocities(self: Probe) usize {
        var count: usize = 0;
        // v is brute-forced... :-(
        var vx: isize = 0;
        while (vx <= 200) : (vx += 1) {
            var vy: isize = -200;
            while (vy <= 200) : (vy += 1) {
                var vel = V2.init(vx, vy);
                const h = self.shoot(vel);
                if (h == std.math.minInt(isize)) continue;
                count += 1;
            }
        }
        return count;
    }
};

test "sample part a 1" {
    const data: []const u8 =
        \\target area: x=20..30, y=-10..-5
    ;

    var probe = Probe.init();
    defer probe.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try probe.process_line(line);
    }

    try testing.expect(probe.shoot(Probe.V2.init(7, 2)) != std.math.minInt(isize));
    try testing.expect(probe.shoot(Probe.V2.init(6, 3)) != std.math.minInt(isize));
    try testing.expect(probe.shoot(Probe.V2.init(9, 0)) != std.math.minInt(isize));

    try testing.expect(probe.shoot(Probe.V2.init(17, -4)) == std.math.minInt(isize));

    const highest = probe.find_highest_position();
    try testing.expect(highest == 45);
}

test "sample part a b" {
    const data: []const u8 =
        \\target area: x=20..30, y=-10..-5
    ;

    var probe = Probe.init();
    defer probe.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try probe.process_line(line);
    }

    const count = probe.count_velocities();
    try testing.expect(count == 112);
}
