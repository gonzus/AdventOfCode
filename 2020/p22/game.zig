const std = @import("std");
const testing = std.testing;

const allocator = std.heap.page_allocator;

pub const Game = struct {
    const SIZE = 10_000;

    pub const Mode = enum {
        Simple,
        Recursive,
    };

    const Cards = struct {
        values: [SIZE]usize,
        top: usize,
        bot: usize,
        buf: [SIZE]u8,

        pub fn init() Cards {
            var self = Cards{
                .values = [_]usize{0} ** SIZE,
                .top = 0,
                .bot = 0,
                .buf = undefined,
            };
            return self;
        }

        pub fn clone(self: Cards, count: usize) Cards {
            var other = Cards.init();
            var p: usize = self.top;
            while (p < self.top + count) : (p += 1) {
                other.values[other.bot] = self.values[p];
                other.bot += 1;
            }
            return other;
        }

        pub fn empty(self: Cards) bool {
            return self.size() == 0;
        }

        pub fn size(self: Cards) usize {
            return self.bot - self.top;
        }

        pub fn state(self: *Cards) []const u8 {
            var p: usize = 0;
            var c: usize = self.top;
            while (c < self.bot) : (c += 1) {
                if (p > 0) {
                    self.buf[p] = ',';
                    p += 1;
                }
                const s = std.fmt.bufPrint(self.buf[p..], "{}", .{self.values[c]}) catch unreachable;
                p += s.len;
            }
            const s = self.buf[0..p];
            return s;
        }

        pub fn score(self: Cards) usize {
            if (self.top > self.bot) @panic("WTF");
            var total: usize = 0;
            var n: usize = 1;
            var p: usize = self.bot - 1;
            while (p >= self.top) : (p -= 1) {
                const points = n * self.values[p];
                total += points;
                n += 1;
            }
            return total;
        }

        pub fn take_top(self: *Cards) usize {
            if (self.empty()) @panic("EMPTY");
            const card = self.values[self.top];
            self.top += 1;
            return card;
        }

        pub fn put_bottom(self: *Cards, card: usize) void {
            self.values[self.bot] = card;
            self.bot += 1;
        }
    };

    mode: Mode,
    cards: [2]Cards,
    turn: usize,

    pub fn init(mode: Mode) Game {
        var self = Game{
            .mode = mode,
            .cards = undefined,
            .turn = 0,
        };
        self.cards[0] = Cards.init();
        self.cards[1] = Cards.init();
        return self;
    }

    pub fn deinit(self: *Game) void {
        _ = self;
    }

    pub fn add_line(self: *Game, line: []const u8) void {
        if (line.len == 0) return;

        if (std.mem.startsWith(u8, line, "Player ")) {
            var it = std.mem.tokenize(u8, line, " :");
            _ = it.next().?;
            const player = std.fmt.parseInt(usize, it.next().?, 10) catch unreachable;
            self.turn = player - 1;
            return;
        }

        const card = std.fmt.parseInt(usize, line, 10) catch unreachable;
        self.cards[self.turn].put_bottom(card);
    }

    pub fn play(self: *Game) usize {
        const winner = self.play_recursive(0, &self.cards);
        const score = self.get_score(winner);
        return score;
    }

    pub fn play_recursive(self: *Game, level: usize, cards: *[2]Cards) usize {
        // std.debug.warn("GAME level {} - {} vs {} cards\n", .{ level, cards[0].size(), cards[1].size() });
        var seen = std.StringHashMap(void).init(allocator);
        defer seen.deinit();

        var round: usize = 0;
        var winner: usize = 0;
        while (true) : (round += 1) {
            if (self.mode == Mode.Recursive) {
                var state: [2][]const u8 = undefined;
                state[0] = cards[0].state();
                state[1] = cards[1].state();
                const label = std.mem.join(allocator, ":", state[0..]) catch unreachable;
                if (seen.contains(label)) {
                    winner = 0;
                    break;
                }
                _ = seen.put(label, {}) catch unreachable;
            }

            var round_winner: usize = 0;
            var card0 = cards[0].take_top();
            var card1 = cards[1].take_top();
            if (self.mode == Mode.Recursive and card0 <= cards[0].size() and card1 <= cards[1].size()) {
                // recursive play, new game
                var sub_cards: [2]Cards = undefined;
                sub_cards[0] = cards[0].clone(card0);
                sub_cards[1] = cards[1].clone(card1);
                round_winner = self.play_recursive(level + 1, &sub_cards);
            } else {
                // regular play
                if (card0 <= card1) {
                    round_winner = 1;
                }
            }

            // winner card goes first
            if (round_winner == 1) {
                const t = card0;
                card0 = card1;
                card1 = t;
            }
            cards[round_winner].put_bottom(card0);
            cards[round_winner].put_bottom(card1);
            // std.debug.warn("<{}> ROUND {} WINNER {} -- {} {} -- {} {}\n", .{ level, round, round_winner, card0, card1, cards[0].empty(), cards[1].empty() });
            if (cards[0].empty()) {
                winner = 1;
                break;
            }
            if (cards[1].empty()) {
                winner = 0;
                break;
            }
        }
        // std.debug.warn("<{}> WINNER {}\n", .{ level, winner });
        return winner;
    }

    pub fn get_score(self: Game, winner: usize) usize {
        const score = self.cards[winner].score();
        return score;
    }
};

test "sample part a" {
    const data: []const u8 =
        \\Player 1:
        \\9
        \\2
        \\6
        \\3
        \\1
        \\
        \\Player 2:
        \\5
        \\8
        \\4
        \\7
        \\10
    ;

    var game = Game.init(Game.Mode.Simple);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        game.add_line(line);
    }

    const score = game.play();
    try testing.expect(score == 306);
}

test "sample part b" {
    const data: []const u8 =
        \\Player 1:
        \\9
        \\2
        \\6
        \\3
        \\1
        \\
        \\Player 2:
        \\5
        \\8
        \\4
        \\7
        \\10
    ;

    var game = Game.init(Game.Mode.Recursive);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        game.add_line(line);
    }

    const score = game.play();
    try testing.expect(score == 291);
}
