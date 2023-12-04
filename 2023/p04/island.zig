const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Game = struct {
    winning: std.AutoHashMap(usize, void),
    cards: std.AutoHashMap(usize, usize),
    points: usize,

    pub fn init(allocator: Allocator) Game {
        var self = Game{
            .winning = std.AutoHashMap(usize, void).init(allocator),
            .cards = std.AutoHashMap(usize, usize).init(allocator),
            .points = 0,
        };
        return self;
    }

    pub fn deinit(self: *Game) void {
        self.cards.deinit();
        self.winning.deinit();
    }

    pub fn getSumPoints(self: Game) usize {
        return self.points;
    }

    pub fn getTotalCards(self: Game) usize {
        var count: usize = 0;
        var it = self.cards.valueIterator();
        while (it.next()) |value| {
            count += value.*;
        }
        return count;
    }

    pub fn addLine(self: *Game, line: []const u8) !void {
        var colon_it = std.mem.tokenizeScalar(u8, line, ':');
        const card_str = colon_it.next().?;
        const numbers_str = colon_it.next().?;

        var space_it = std.mem.tokenizeScalar(u8, card_str, ' ');
        _ = space_it.next(); // skip "Card "
        const card_id = try std.fmt.parseUnsigned(u8, space_it.next().?, 10);
        var card_entry = try self.cards.getOrPutValue(card_id, 0);
        card_entry.value_ptr.* += 1;
        const current = card_entry.value_ptr.*;

        var count: usize = 0;
        var points: usize = 0;
        self.winning.clearRetainingCapacity();
        var what: usize = 0;
        var numbers_it = std.mem.tokenizeScalar(u8, numbers_str, '|');
        while (numbers_it.next()) |numbers| : (what += 1) {
            var number_it = std.mem.tokenizeScalar(u8, numbers, ' ');
            while (number_it.next()) |num_str| {
                const number = try std.fmt.parseUnsigned(u8, num_str, 10);
                switch (what) {
                    0 => {
                        _ = try self.winning.getOrPut(number);
                    },
                    1 => {
                        if (self.winning.contains(number)) {
                            count += 1;
                            points = if (points == 0) 1 else points * 2;
                        }
                    },
                    else => unreachable,
                }
            }
        }
        self.points += points;
        for (0..count) |p| {
            const won_id = card_id + p + 1;
            var entry = try self.cards.getOrPutValue(won_id, 0);
            entry.value_ptr.* += current;
        }
    }
};

test "sample part 1" {
    const data =
        \\Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53
        \\Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19
        \\Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1
        \\Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83
        \\Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36
        \\Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11
    ;

    var game = Game.init(std.testing.allocator);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }

    const points = game.getSumPoints();
    const expected = @as(usize, 13);
    try testing.expectEqual(expected, points);
}

test "sample part 2" {
    const data =
        \\Card 1: 41 48 83 86 17 | 83 86  6 31 17  9 48 53
        \\Card 2: 13 32 20 16 61 | 61 30 68 82 17 32 24 19
        \\Card 3:  1 21 53 59 44 | 69 82 63 72 16 21 14  1
        \\Card 4: 41 92 73 84 69 | 59 84 76 51 58  5 54 83
        \\Card 5: 87 83 26 28 32 | 88 30 70 12 93 22 82 36
        \\Card 6: 31 18 13 56 72 | 74 77 10 23 35 67 36 11
    ;

    var game = Game.init(std.testing.allocator);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }

    const total = game.getTotalCards();
    const expected = @as(usize, 30);
    try testing.expectEqual(expected, total);
}
