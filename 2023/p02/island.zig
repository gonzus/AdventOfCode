const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

const Color = enum(u8) {
    red = 0,
    green = 1,
    blue = 2,

    pub fn parse(str: []const u8) !Color {
        return switch (str[0]) {
            'r' => .red,
            'g' => .green,
            'b' => .blue,
            else => error.InvalidColor,
        };
    }
};

pub const ColorSet = struct {
    const NUM_COLORS: usize = std.meta.tags(Color).len;
    cubes: [NUM_COLORS]usize,

    pub fn init() ColorSet {
        var self = ColorSet{
            .cubes = [_]usize{0} ** NUM_COLORS,
        };
        return self;
    }

    pub fn config(r: u8, g: u8, b: u8) ColorSet {
        var self = ColorSet{
            .cubes = [_]usize{ r, g, b },
        };
        return self;
    }

    pub fn reset(self: *ColorSet) void {
        for (&self.cubes) |*cube| {
            cube.* = 0;
        }
    }

    pub fn larger(self: ColorSet, other: ColorSet) bool {
        for (self.cubes, 0..) |_, pos| {
            if (self.cubes[pos] > other.cubes[pos]) return true;
        }
        return false;
    }

    pub fn parse(str: []const u8) !ColorSet {
        var self = ColorSet.init();
        var color_it = std.mem.tokenizeScalar(u8, str, ',');
        while (color_it.next()) |color| {
            var pos: usize = 0;
            var count: usize = 0;
            var count_it = std.mem.tokenizeScalar(u8, color, ' ');
            while (count_it.next()) |count_str| {
                switch (pos) {
                    0 => count = try std.fmt.parseUnsigned(u8, count_str, 10),
                    1 => {
                        const c = try Color.parse(count_str);
                        self.cubes[@intFromEnum(c)] = count;
                    },
                    else => return error.InvalidState,
                }
                pos += 1;
            }
        }
        return self;
    }
};

const GAME_CONFIG = ColorSet.config(12, 13, 14);

pub const Walk = struct {
    best: ColorSet,
    sum_possible_ids: usize,
    sum_powers: usize,

    pub fn init(allocator: Allocator) Walk {
        _ = allocator;
        var self = Walk{
            .best = ColorSet.init(),
            .sum_possible_ids = 0,
            .sum_powers = 0,
        };
        return self;
    }

    pub fn deinit(self: *Walk) void {
        _ = self;
    }

    pub fn registerBest(self: *Walk, round: ColorSet) void {
        for (GAME_CONFIG.cubes, 0..) |_, pos| {
            if (self.best.cubes[pos] >= round.cubes[pos]) continue;
            self.best.cubes[pos] = round.cubes[pos];
        }
    }

    pub fn registerPower(self: *Walk) void {
        var power: usize = 1;
        for (self.best.cubes) |c| {
            power *= c;
        }
        self.sum_powers += power;
        self.best.reset();
    }

    pub fn getSumPossibleGameIds(self: Walk) usize {
        return self.sum_possible_ids;
    }

    pub fn getSumPowers(self: Walk) usize {
        return self.sum_powers;
    }

    pub fn addLine(self: *Walk, line: []const u8) !void {
        var colon_it = std.mem.tokenizeScalar(u8, line, ':');
        const game_str = colon_it.next().?;
        const round_str = colon_it.next().?;

        var space_it = std.mem.tokenizeScalar(u8, game_str, ' ');
        _ = space_it.next(); // skip "Game "
        const game_id: usize = try std.fmt.parseUnsigned(u8, space_it.next().?, 10);

        var invalid_count: usize = 0;
        var game_it = std.mem.tokenizeScalar(u8, round_str, ';');
        while (game_it.next()) |game| {
            const round = try ColorSet.parse(game);
            if (round.larger(GAME_CONFIG)) {
                invalid_count += 1;
            }
            self.registerBest(round);
        }
        if (invalid_count == 0) {
            self.sum_possible_ids += game_id;
        }
        self.registerPower();
    }
};

test "sample part 1" {
    const data =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    ;

    var walk = Walk.init(std.testing.allocator);
    defer walk.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try walk.addLine(line);
    }

    const sum = walk.getSumPossibleGameIds();
    const expected = @as(usize, 8);
    try testing.expectEqual(expected, sum);
}

test "sample part 2" {
    const data =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    ;

    var walk = Walk.init(std.testing.allocator);
    defer walk.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try walk.addLine(line);
    }

    const sum = walk.getSumPowers();
    const expected = @as(usize, 2286);
    try testing.expectEqual(expected, sum);
}
