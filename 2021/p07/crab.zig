const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const Crab = struct {
    pub const Mode = enum {
        Unit,
        Sum,
    };

    mode: Mode,
    pMin: isize,
    pMax: isize,
    pos: std.ArrayList(isize),

    pub fn init(mode: Mode) Crab {
        var self = Crab{
            .mode = mode,
            .pMin = std.math.maxInt(isize),
            .pMax = std.math.minInt(isize),
            .pos = std.ArrayList(isize).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Crab) void {
        self.pos.deinit();
    }

    pub fn process_line(self: *Crab, data: []const u8) void {
        var it = std.mem.split(u8, data, ",");
        while (it.next()) |num| {
            const n = std.fmt.parseInt(isize, num, 10) catch unreachable;
            if (self.pMin > n) {
                self.pMin = n;
            }
            if (self.pMax < n) {
                self.pMax = n;
            }
            self.pos.append(n) catch unreachable;
        }
        // std.debug.warn("COUNT {}, MIN {}, MAX {}\n", .{ self.pos.items.len, self.pMin, self.pMax });
    }

    pub fn find_min_fuel_consumption(self: Crab) usize {
        var min: usize = std.math.maxInt(usize);
        var target = self.pMin;
        while (target <= self.pMax) : (target += 1) {
            const fuel = self.compute_total_fuel_to_target(target);
            if (min > fuel) {
                min = fuel;
            }
        }
        return min;
    }

    fn compute_total_fuel_to_target(self: Crab, target: isize) usize {
        var total: usize = 0;
        for (self.pos.items) |pos| {
            const dist = @intCast(usize, std.math.absInt(target - pos) catch unreachable);
            const fuel = switch (self.mode) {
                .Unit => dist,
                .Sum => dist * (dist + 1) / 2,
            };
            // std.debug.warn("FROM {} to {}: {} {}\n", .{ target, pos, dist, fuel });
            total += fuel;
        }
        // std.debug.warn("TOTAL FROM {}: {}\n", .{ target, total });
        return total;
    }
};

test "sample part a" {
    const data: []const u8 =
        \\16,1,2,0,4,2,7,1,2,14
    ;

    var crab = Crab.init(Crab.Mode.Unit);
    defer crab.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        crab.process_line(line);
    }
    const min = crab.find_min_fuel_consumption();
    try testing.expect(min == 37);
}

test "sample part b" {
    const data: []const u8 =
        \\16,1,2,0,4,2,7,1,2,14
    ;

    var crab = Crab.init(Crab.Mode.Sum);
    defer crab.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        crab.process_line(line);
    }
    const min = crab.find_min_fuel_consumption();
    try testing.expect(min == 168);
}
