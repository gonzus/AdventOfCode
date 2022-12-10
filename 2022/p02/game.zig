const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Move = enum(u8) {
    Rock = 1,
    Paper = 2,
    Scissors = 3,

    pub fn score(self: Move) usize {
        return switch (self) {
            .Rock => 1,
            .Paper => 2,
            .Scissors => 3,
        };
    }
};

pub const Result = enum(usize) {
    Win = 1,
    Draw = 2,
    Lose = 3,

    pub fn score(self: Result) usize {
        return switch (self) {
            .Win => 6,
            .Draw => 3,
            .Lose => 0,
        };
    }
};

pub const Mine = enum(u8) {
    X = 1, //     rock | must lose
    Y = 2, //    paper | must draw
    Z = 3, // scissors | must win

    pub fn parse(c: u8) Mine {
        return switch (c) {
            'X' => .X,
            'Y' => .Y,
            'Z' => .Z,
            else => unreachable,
        };
    }

    pub fn as_move(self: Mine) Move {
        return switch (self) {
            .X => .Rock,
            .Y => .Paper,
            .Z => .Scissors,
        };
    }

    pub fn as_result(self: Mine) Result {
        return switch (self) {
            .X => .Lose,
            .Y => .Draw,
            .Z => .Win,
        };
    }
};

pub const Oponent = enum(u8) {
    A = 1, // rock
    B = 2, // paper
    C = 3, // scissors

    pub fn parse(c: u8) Oponent {
        return switch (c) {
            'A' => .A,
            'B' => .B,
            'C' => .C,
            else => unreachable,
        };
    }

    pub fn as_move(self: Oponent) Move {
        return switch (self) {
            .A => .Rock,
            .B => .Paper,
            .C => .Scissors,
        };
    }
};

pub const Round = struct {
    o: Oponent,
    m: Mine,

    pub fn init(oponent: Oponent, mine: Mine) Round {
        var self = Round{
            .o = oponent,
            .m = mine,
        };
        return self;
    }
};

pub const Game = struct {
    rounds: std.ArrayList(Round),

    pub fn init(allocator: Allocator) Game {
        var self = Game{
            .rounds = std.ArrayList(Round).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Game) void {
        self.rounds.deinit();
    }

    fn move_for_desired_result_given_oponent(desired: Result, oponent: Move) Move {
        return switch (desired) {
            .Lose => switch (oponent) {
                .Rock => .Scissors,
                .Paper => .Rock,
                .Scissors => .Paper,
            },
            .Draw => oponent,
            .Win => switch (oponent) {
                .Rock => .Paper,
                .Paper => .Scissors,
                .Scissors => .Rock,
            },
        };
    }

    fn result_from_moves(mine: Move, oponent: Move) Result {
        return switch (mine) {
            .Rock => switch (oponent) {
                .Rock => .Draw,
                .Paper => .Lose,
                .Scissors => .Win,
            },
            .Paper => switch (oponent) {
                .Rock => .Win,
                .Paper => .Draw,
                .Scissors => .Lose,
            },
            .Scissors => switch (oponent) {
                .Rock => .Lose,
                .Paper => .Win,
                .Scissors => .Draw,
            },
        };
    }

    pub fn add_line(self: *Game, line: []const u8) !void {
        var o: Oponent = undefined;
        var m: Mine = undefined;
        var pos: usize = 0;
        var it = std.mem.tokenize(u8, line, " ");
        while (it.next()) |what| : (pos += 1) {
            switch (pos) {
                0 => o = Oponent.parse(what[0]),
                1 => m = Mine.parse(what[0]),
                else => unreachable,
            }
        }
        try self.rounds.append(Round.init(o, m));
    }

    pub fn get_score(self: Game, based_on_outcome: bool) usize {
        var score: usize = 0;
        for (self.rounds.items) |round| {
            var mm: Move = round.m.as_move();
            var mo: Move = round.o.as_move();
            if (based_on_outcome) {
                const desired = round.m.as_result();
                mm = move_for_desired_result_given_oponent(desired, mo);
            }
            const result = result_from_moves(mm, mo);
            score += result.score();
            score += mm.score();
        }
        return score;
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\A Y
        \\B X
        \\C Z
    ;

    var game = Game.init(std.testing.allocator);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.add_line(line);
    }

    const score = game.get_score(false);
    try testing.expectEqual(score, 15);
}

test "sample part 2" {
    const data: []const u8 =
        \\A Y
        \\B X
        \\C Z
    ;

    var game = Game.init(std.testing.allocator);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.add_line(line);
    }

    const score = game.get_score(true);
    try testing.expectEqual(score, 12);
}
