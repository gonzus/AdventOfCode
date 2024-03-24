const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const SimpleDeque = @import("./util/queue.zig").SimpleDeque;

const Allocator = std.mem.Allocator;

pub const Game = struct {
    const Deque = SimpleDeque(usize);

    players: usize,
    points: usize,
    elves: std.AutoHashMap(usize, usize),
    circle: Deque,

    pub fn init(allocator: Allocator) Game {
        return .{
            .players = 0,
            .points = 0,
            .elves = std.AutoHashMap(usize, usize).init(allocator),
            .circle = Deque.init(allocator),
        };
    }

    pub fn deinit(self: *Game) void {
        defer self.elves.deinit();
        defer self.circle.deinit();
    }

    pub fn addLine(self: *Game, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        self.players = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        _ = it.next();
        _ = it.next();
        _ = it.next();
        _ = it.next();
        _ = it.next();
        self.points = try std.fmt.parseUnsigned(usize, it.next().?, 10);
    }

    pub fn playGame(self: *Game, marble_multiplier: usize) !usize {
        self.elves.clearRetainingCapacity();
        self.circle.clear();
        const max_marble = self.points * marble_multiplier;
        for (0..max_marble + 1) |marble| {
            const elf = marble % self.players;
            if (marble > 0 and marble % 23 == 0) {
                try self.circle.rotate(7);
                const e = try self.elves.getOrPutValue(elf, 0);
                e.value_ptr.* += marble + try self.circle.pop();
                try self.circle.rotate(-1);
            } else {
                try self.circle.rotate(-1);
                try self.circle.append(marble);
            }
        }
        var best: usize = 0;
        var it = self.elves.valueIterator();
        while (it.next()) |e| {
            if (best < e.*) best = e.*;
        }
        return best;
    }
};

test "sample part 1 example" {
    const data =
        \\9 players; last marble is worth 23 points
    ;

    var game = Game.init(testing.allocator);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }

    const score = try game.playGame(1);
    const expected = @as(usize, 32);
    try testing.expectEqual(expected, score);
}

test "sample part 1 case A" {
    const data =
        \\10 players; last marble is worth 1618 points
    ;

    var game = Game.init(testing.allocator);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }

    const score = try game.playGame(1);
    const expected = @as(usize, 8317);
    try testing.expectEqual(expected, score);
}

test "sample part 1 case B" {
    const data =
        \\13 players; last marble is worth 7999 points
    ;

    var game = Game.init(testing.allocator);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }

    const score = try game.playGame(1);
    const expected = @as(usize, 146373);
    try testing.expectEqual(expected, score);
}

test "sample part 1 case C" {
    const data =
        \\17 players; last marble is worth 1104 points
    ;

    var game = Game.init(testing.allocator);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }

    const score = try game.playGame(1);
    const expected = @as(usize, 2764);
    try testing.expectEqual(expected, score);
}

test "sample part 1 case D" {
    const data =
        \\21 players; last marble is worth 6111 points
    ;

    var game = Game.init(testing.allocator);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }

    const score = try game.playGame(1);
    const expected = @as(usize, 54718);
    try testing.expectEqual(expected, score);
}

test "sample part 1 case E" {
    const data =
        \\30 players; last marble is worth 5807 points
    ;

    var game = Game.init(testing.allocator);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }

    const score = try game.playGame(1);
    const expected = @as(usize, 37305);
    try testing.expectEqual(expected, score);
}
