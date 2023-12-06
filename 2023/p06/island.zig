const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Competition = struct {
    const Race = struct {
        time: u64,
        distance: u64,

        pub fn init(time: u64, distance: u64) Race {
            var self = Race{
                .time = time,
                .distance = distance,
            };
            return self;
        }

        pub fn getWinningWays(self: Race) u64 {
            const t: f64 = @floatFromInt(self.time);
            const d: f64 = @floatFromInt(self.distance);
            const delta = std.math.sqrt(t * t - 4 * d);
            const hi = (t + delta) / 2.0;
            const lo = (t - delta) / 2.0;
            const h = @ceil(hi - 1);
            const l = @floor(lo + 1);
            const n: u64 = @intFromFloat(h - l + 1);
            return n;
        }
    };

    single_race: bool,
    races: std.ArrayList(Race),

    pub fn init(allocator: Allocator, single_race: bool) Competition {
        var self = Competition{
            .single_race = single_race,
            .races = std.ArrayList(Race).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Competition) void {
        self.races.deinit();
    }

    pub fn addLine(self: *Competition, line: []const u8) !void {
        var chunk_it = std.mem.tokenizeScalar(u8, line, ':');

        const left_chunk = chunk_it.next().?;
        const is_time = std.mem.eql(u8, left_chunk, "Time");

        const right_chunk = chunk_it.next().?;
        var number_it = std.mem.tokenizeScalar(u8, right_chunk, ' ');
        var pos: usize = 0;
        var num: u64 = 0;
        while (number_it.next()) |num_str| {
            for (num_str) |c| {
                num *= 10;
                num += c - '0';
            }
            if (!self.single_race) {
                if (is_time) {
                    const r = Race.init(num, 0);
                    try self.races.append(r);
                } else {
                    self.races.items[pos].distance = num;
                }
                num = 0;
                pos += 1;
            }
        }
        if (self.single_race) {
            if (is_time) {
                const r = Race.init(num, 0);
                try self.races.append(r);
            } else {
                self.races.items[pos].distance = num;
            }
        }
    }

    pub fn show(self: Competition) void {
        std.debug.print("Competition with {} races\n", .{self.races.items.len});

        std.debug.print("Time:", .{});
        for (self.races.items) |r| {
            std.debug.print(" {}", .{r.time});
        }
        std.debug.print("\n", .{});

        std.debug.print("Distance:", .{});
        for (self.races.items) |r| {
            std.debug.print(" {}", .{r.distance});
        }
        std.debug.print("\n", .{});
    }

    pub fn getProductWinningWays(self: *Competition) u64 {
        var product: u64 = 1;
        for (self.races.items) |r| {
            product *= r.getWinningWays();
        }
        return product;
    }
};

test "sample part 1" {
    const data =
        \\Time:      7  15   30
        \\Distance:  9  40  200
    ;

    var competition = Competition.init(std.testing.allocator, false);
    defer competition.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try competition.addLine(line);
    }
    // competition.show();

    const prod = competition.getProductWinningWays();
    const expected = @as(u64, 288);
    try testing.expectEqual(expected, prod);
}

test "sample part 2" {
    const data =
        \\Time:      7  15   30
        \\Distance:  9  40  200
    ;

    var competition = Competition.init(std.testing.allocator, true);
    defer competition.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try competition.addLine(line);
    }
    // competition.show();

    const prod = competition.getProductWinningWays();
    const expected = @as(u64, 71503);
    try testing.expectEqual(expected, prod);
}
