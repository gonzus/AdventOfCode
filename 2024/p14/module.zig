const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const INFINITY = std.math.maxInt(usize);

    const WIDTH_FULL = 101;
    const HEIGHT_FULL = 103;
    const WIDTH_TEST = 11;
    const HEIGHT_TEST = 7;

    const ITERATIONS_P1 = 100;
    const ITERATIONS_P2 = 10000;

    const V2 = struct {
        x: isize,
        y: isize,

        pub fn init() V2 {
            return .{ .x = 0, .y = 0 };
        }
    };

    const Robot = struct {
        pos: V2,
        vel: V2,

        pub fn init() Robot {
            return .{ .pos = V2.init(), .vel = V2.init() };
        }
    };

    full: bool,
    rows: usize,
    cols: usize,
    robots: std.ArrayList(Robot),
    best_dist: usize,
    best_step: usize,

    pub fn init(allocator: Allocator, full: bool) Module {
        var self = Module{
            .full = full,
            .rows = 0,
            .cols = 0,
            .robots = std.ArrayList(Robot).init(allocator),
            .best_dist = INFINITY,
            .best_step = 0,
        };
        if (full) {
            self.rows = HEIGHT_FULL;
            self.cols = WIDTH_FULL;
        } else {
            self.rows = HEIGHT_TEST;
            self.cols = WIDTH_TEST;
        }
        return self;
    }

    pub fn deinit(self: *Module) void {
        self.robots.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        var robot = Robot.init();
        var it = std.mem.tokenizeAny(u8, line, "pv=, ");
        var p: usize = 0;
        while (it.next()) |chunk| : (p += 1) {
            const n = try std.fmt.parseInt(isize, chunk, 10);
            switch (p) {
                0 => robot.pos.x = n,
                1 => robot.pos.y = n,
                2 => robot.vel.x = n,
                3 => robot.vel.y = n,
                else => return error.TooManyValues,
            }
        }
        try self.robots.append(robot);
    }

    // pub fn show(self: Module, step: usize) void {
    //     std.debug.print("STEP {}: Robots: {}\n", .{ step + 1, self.robots.items.len });
    //     for (0..self.rows) |y| {
    //         for (0..self.cols) |x| {
    //             var count: u8 = 0;
    //             for (self.robots.items) |r| {
    //                 const ux: usize = @intCast(r.pos.x);
    //                 const uy: usize = @intCast(r.pos.y);
    //                 if (x == ux and y == uy) {
    //                     count += 1;
    //                 }
    //             }
    //             const l: u8 = if (count == 0) ' ' else '0' + count;
    //             std.debug.print("{c}", .{l});
    //         }
    //         std.debug.print("\n", .{});
    //     }
    // }

    fn recordClustering(self: *Module, step: usize) void {
        const mx = self.cols / 2;
        const my = self.rows / 2;
        var dist: usize = 0;
        for (self.robots.items) |r| {
            const ux: usize = @intCast(r.pos.x);
            const uy: usize = @intCast(r.pos.y);
            dist += if (ux > mx) (ux - mx) else (mx - ux);
            dist += if (uy > my) (uy - my) else (my - uy);
        }
        if (self.best_dist <= dist) return;

        self.best_dist = dist;
        self.best_step = step + 1;
        // self.show(step);
    }

    fn iterate(self: *Module, top: usize) !void {
        const irows: isize = @intCast(self.rows);
        const icols: isize = @intCast(self.cols);
        for (0..top) |seconds| {
            for (self.robots.items) |*r| {
                r.pos.x = @intCast(@mod(r.pos.x + r.vel.x, icols));
                r.pos.y = @intCast(@mod(r.pos.y + r.vel.y, irows));
            }
            self.recordClustering(seconds);
        }
    }

    pub fn getSafetyFactor(self: *Module) !usize {
        try self.iterate(ITERATIONS_P1);
        const mx = self.cols / 2;
        const my = self.rows / 2;
        var ul: usize = 0;
        var ur: usize = 0;
        var ll: usize = 0;
        var lr: usize = 0;
        for (self.robots.items) |*r| {
            if (r.pos.x == mx or r.pos.y == my) continue;
            if (r.pos.x < mx) {
                if (r.pos.y < my) {
                    ul += 1;
                } else {
                    ll += 1;
                }
            } else {
                if (r.pos.y < my) {
                    ur += 1;
                } else {
                    lr += 1;
                }
            }
        }
        const factor: usize = ul * ur * ll * lr;
        return factor;
    }

    pub fn findTree(self: *Module) !usize {
        try self.iterate(ITERATIONS_P2);
        return self.best_step;
    }
};

test "sample part 1" {
    const data =
        \\p=0,4 v=3,-3
        \\p=6,3 v=-1,-3
        \\p=10,3 v=-1,2
        \\p=2,0 v=2,-1
        \\p=0,0 v=1,3
        \\p=3,0 v=-2,-2
        \\p=7,6 v=-1,-3
        \\p=3,0 v=-1,-2
        \\p=9,3 v=2,3
        \\p=7,3 v=-1,2
        \\p=2,4 v=2,-3
        \\p=9,5 v=-3,-3
    ;

    var module = Module.init(testing.allocator, false);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getSafetyFactor();
    const expected = @as(usize, 12);
    try testing.expectEqual(expected, count);
}
