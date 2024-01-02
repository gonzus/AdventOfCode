const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Race = struct {
    const StringId = StringTable.StringId;

    const Reindeer = struct {
        name: StringId = 0,
        speed: usize = 0,
        fly_time: usize = 0,
        rest_time: usize = 0,
        distance: usize = 0,
        flying: bool = false,
        time_left: usize = 0,
        points: usize = 0,

        pub fn getDistanceTravelled(self: Reindeer, elapsed: usize) usize {
            const cycle = self.fly_time + self.rest_time;
            const full = elapsed / cycle;
            const extra = elapsed % cycle;
            const bump = @min(extra, self.fly_time);
            const distance = self.speed * (full * self.fly_time + bump);
            return distance;
        }

        pub fn advanceOneSecond(self: *Reindeer) void {
            if (self.time_left == 0) {
                if (self.flying) {
                    self.flying = false;
                    self.time_left = self.rest_time;
                } else {
                    self.flying = true;
                    self.time_left = self.fly_time;
                }
            }
            self.time_left -= 1;
            if (self.flying) {
                self.distance += self.speed;
            }
        }
    };

    allocator: Allocator,
    strtab: StringTable,
    reindeers: std.ArrayList(Reindeer),

    pub fn init(allocator: Allocator) Race {
        const self = Race{
            .allocator = allocator,
            .strtab = StringTable.init(allocator),
            .reindeers = std.ArrayList(Reindeer).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Race) void {
        self.reindeers.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Race, line: []const u8) !void {
        var pos: usize = 0;
        var reindeer = Reindeer{};
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        while (it.next()) |chunk| : (pos += 1) {
            switch (pos) {
                0 => reindeer.name = try self.strtab.add(chunk),
                3 => reindeer.speed = try std.fmt.parseUnsigned(usize, chunk, 10),
                6 => reindeer.fly_time = try std.fmt.parseUnsigned(usize, chunk, 10),
                13 => reindeer.rest_time = try std.fmt.parseUnsigned(usize, chunk, 10),
                else => {},
            }
        }
        try self.reindeers.append(reindeer);
    }

    pub fn show(self: Race) void {
        std.debug.print("Race with {} reindeers\n", .{self.reindeers.items.len});
        for (self.reindeers.items) |r| {
            std.debug.print("  {d}:{s} => speed {} km/s, fly time {} s, rest time {} s\n", .{ r.name, self.strtab.get_str(r.name) orelse "***", r.speed, r.fly_time, r.rest_time });
        }
    }

    pub fn getWinnerDistanceAfter(self: *Race, elapsed: usize) !usize {
        var best: usize = 0;
        for (self.reindeers.items) |r| {
            const distance = r.getDistanceTravelled(elapsed);
            if (best < distance) best = distance;
        }
        return best;
    }

    pub fn getWinnerPointsAfter(self: *Race, elapsed: usize) !usize {
        for (0..elapsed) |_| {
            var best: usize = 0;
            for (self.reindeers.items) |*r| {
                r.advanceOneSecond();
                if (best < r.distance) best = r.distance;
            }
            for (self.reindeers.items) |*r| {
                if (r.distance != best) continue;
                r.points += 1;
            }
        }
        var best: usize = 0;
        for (self.reindeers.items) |r| {
            if (best < r.points) best = r.points;
        }
        return best;
    }
};

test "sample part 1" {
    const data =
        \\Comet can fly 14 km/s for 10 seconds, but then must rest for 127 seconds.
        \\Dancer can fly 16 km/s for 11 seconds, but then must rest for 162 seconds.
    ;

    var race = Race.init(std.testing.allocator);
    defer race.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try race.addLine(line);
    }
    // race.show();

    const distance = try race.getWinnerDistanceAfter(1000);
    const expected = @as(usize, 1120);
    try testing.expectEqual(expected, distance);
}

test "sample part 2" {
    const data =
        \\Comet can fly 14 km/s for 10 seconds, but then must rest for 127 seconds.
        \\Dancer can fly 16 km/s for 11 seconds, but then must rest for 162 seconds.
    ;

    var race = Race.init(std.testing.allocator);
    defer race.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try race.addLine(line);
    }
    // race.show();

    const points = try race.getWinnerPointsAfter(1000);
    const expected = @as(usize, 689);
    try testing.expectEqual(expected, points);
}
