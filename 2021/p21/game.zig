const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const Game = struct {
    const BOARD_SIZE = 10;

    const Player = struct {
        name: usize,
        pos: usize,
        score: usize,

        pub fn init(name: usize, start: usize) Player {
            var self = Player{
                .name = name,
                .pos = start - 1,
                .score = 0,
            };
            return self;
        }

        pub fn won(self: Player, needed: usize) bool {
            return self.score >= needed;
        }

        pub fn move_by(self: *Player, amount: usize) void {
            self.pos = (self.pos + amount) % 10;
            self.score += self.pos + 1;
            // std.debug.warn("PLAYER {} moved to {}, score now is {}\n", .{ self.name, self.pos + 1, self.score });
        }
    };

    const Deterministic = struct {
        const DIE_SIZE = 100;

        face: usize,
        rolls: usize,

        pub fn init() Deterministic {
            var self = Deterministic{
                .face = 1,
                .rolls = 0,
            };
            return self;
        }

        pub fn roll(self: *Deterministic) usize {
            const num = self.face;
            self.face = self.face % DIE_SIZE + 1;
            self.rolls += 1;
            // std.debug.warn("ROLL #{}: {}\n", .{ self.rolls, num });
            return num;
        }

        pub fn multi_roll(self: *Deterministic, rolls: usize) usize {
            var num: usize = 0;
            var r: usize = 0;
            while (r < rolls) : (r += 1) {
                num += self.roll();
            }
            return num;
        }
    };

    pub const Dirac = struct {
        const NEEDED = 21;

        const Roll = struct {
            value: usize,
            mult: usize,
        };

        const Rolls = [_]Roll{
            Roll{ .value = 3, .mult = 1 },
            Roll{ .value = 4, .mult = 3 },
            Roll{ .value = 5, .mult = 6 },
            Roll{ .value = 6, .mult = 7 },
            Roll{ .value = 7, .mult = 6 },
            Roll{ .value = 8, .mult = 3 },
            Roll{ .value = 9, .mult = 1 },
        };

        pub fn init() Dirac {
            var self = Dirac{};
            return self;
        }

        fn walk(self: *Dirac, pos0: usize, score0: usize, win0: *usize, pos1: usize, score1: usize, win1: *usize, mult: usize) void {
            if (score1 >= NEEDED) {
                win1.* += mult;
                return;
            }
            for (Rolls) |roll| {
                const next_pos = (pos0 + roll.value) % BOARD_SIZE;
                const next_score = score0 + next_pos + 1;
                self.walk(pos1, score1, win1, next_pos, next_score, win0, mult * roll.mult);
            }
        }

        pub fn count_wins(self: *Dirac, pos0: usize, pos1: usize, win0: *usize, win1: *usize) void {
            self.walk(pos0, 0, win0, pos1, 0, win1, 1);
            // std.debug.warn("WINS 0 = {} -- 1 = {}\n", .{ win0.*, win1.* });
        }
    };

    players: [2]Player,
    winner: usize,
    deterministic: Deterministic,
    dirac: Dirac,

    pub fn init() Game {
        var self = Game{
            .players = undefined,
            .winner = std.math.maxInt(usize),
            .deterministic = Deterministic.init(),
            .dirac = Dirac.init(),
        };
        return self;
    }

    pub fn deinit(_: *Game) void {}

    pub fn process_line(self: *Game, data: []const u8) !void {
        var num: usize = 0;
        var pos: usize = 0;
        var p: usize = 0;
        var it = std.mem.split(u8, data, " ");
        while (it.next()) |str| : (p += 1) {
            if (p == 1) {
                num = std.fmt.parseInt(usize, str, 10) catch unreachable;
                continue;
            }
            if (p == 4) {
                pos = std.fmt.parseInt(usize, str, 10) catch unreachable;
                self.players[num - 1] = Player.init(num, pos);
                continue;
            }
        }
    }

    pub fn deterministic_play_until_win(self: *Game, winning_score: usize) void {
        var p: usize = 0;
        while (true) {
            const roll = self.deterministic.multi_roll(3);
            self.players[p].move_by(roll);
            if (self.players[p].won(winning_score)) {
                self.winner = p;
                break;
            }
            p = 1 - p;
        }
    }

    pub fn deterministic_weigthed_score_looser(self: *Game) usize {
        const looser = 1 - self.winner;
        const score = self.players[looser].score * self.deterministic.rolls;
        return score;
    }

    pub fn dirac_count_wins(self: *Game, win0: *usize, win1: *usize) void {
        self.dirac.walk(self.players[0].pos, 0, win0, self.players[1].pos, 0, win1, 1);
    }

    pub fn dirac_best_score(self: *Game) usize {
        var win0: usize = 0;
        var win1: usize = 0;
        self.dirac_count_wins(&win0, &win1);
        const best = if (win0 > win1) win0 else win1;
        return best;
    }
};

test "sample part a" {
    const data: []const u8 =
        \\Player 1 starting position: 4
        \\Player 2 starting position: 8
    ;

    var game = Game.init();
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.process_line(line);
    }

    game.deterministic_play_until_win(1000);
    const score = game.deterministic_weigthed_score_looser();
    try testing.expect(score == 739785);
}

test "sample part b" {
    const data: []const u8 =
        \\Player 1 starting position: 4
        \\Player 2 starting position: 8
    ;

    var game = Game.init();
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.process_line(line);
    }

    var win0: usize = 0;
    var win1: usize = 0;
    game.dirac_count_wins(&win0, &win1);
    try testing.expect(win0 == 444356092776315);
    try testing.expect(win1 == 341960390180808);
}
