const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Game = struct {
    const HAND_CARDS = 5;
    const JOKER_RANK = 1;

    const Rank = struct {
        char: u8,
        value: usize,

        pub fn init(char: u8) Rank {
            var self = Rank{
                .char = char,
                .value = switch (char) {
                    '2'...'9' => char - '0',
                    'T' => 10,
                    'J' => 11,
                    'Q' => 12,
                    'K' => 13,
                    'A' => 14,
                    else => 0,
                },
            };
            return self;
        }

        pub fn rankValue(self: Rank, use_joker: bool) usize {
            if (use_joker and self.char == 'J') return JOKER_RANK;
            return self.value;
        }
    };

    const Kind = enum {
        high_card,
        one_pair,
        two_pair,
        three_of_a_kind,
        full_house,
        four_of_a_kind,
        five_of_a_kind,
    };

    const Counter = struct {
        char: u8,
        count: usize,

        pub fn greaterThan(_: void, l: Counter, r: Counter) bool {
            return l.count > r.count;
        }
    };

    const Hand = struct {
        cards: [HAND_CARDS]Rank,
        card_pos: usize,
        bid: usize,
        pos: usize,

        pub fn init() Hand {
            var self = Hand{
                .cards = undefined,
                .card_pos = 0,
                .bid = 0,
                .pos = 0,
            };
            return self;
        }

        pub fn initFull(str: []const u8) Hand {
            var self = Hand.init();
            for (str) |c| {
                try self.addCard(c);
            }
            return self;
        }

        pub fn addCard(self: *Hand, c: u8) !void {
            self.cards[self.card_pos] = Rank.init(c);
            self.card_pos += 1;
        }

        pub fn computePos(self: *Hand, use_joker: bool) !void {
            self.pos = try self.getPos(use_joker);
        }

        pub fn lessThan(_: void, l: Hand, r: Hand) bool {
            return l.pos < r.pos;
        }

        fn getKind(self: Hand, use_joker: bool) !Kind {
            if (self.card_pos != HAND_CARDS) return error.InvalidHand;
            var counter: [256]Counter = undefined;
            for (counter, 0..) |_, p| {
                counter[p].char = @intCast(p);
                counter[p].count = 0;
            }
            for (self.cards) |r| {
                counter[r.char].count += 1;
            }
            var joker_count: usize = 0;
            if (use_joker) {
                joker_count = counter['J'].count;
                counter['J'].count = 0;
            }
            std.sort.heap(Counter, &counter, {}, Counter.greaterThan);
            if (joker_count == 5) return .five_of_a_kind;
            if (joker_count == 4) return .five_of_a_kind;
            if (joker_count == 3) {
                if (counter[0].count == 2) {
                    return .five_of_a_kind;
                }
                return .four_of_a_kind;
            }
            if (joker_count == 2) {
                if (counter[0].count == 3) {
                    return .five_of_a_kind;
                }
                if (counter[0].count == 2) {
                    return .four_of_a_kind;
                }
                return .three_of_a_kind;
            }
            if (joker_count == 1) {
                if (counter[0].count == 4) {
                    return .five_of_a_kind;
                }
                if (counter[0].count == 3) {
                    return .four_of_a_kind;
                }
                if (counter[0].count == 2) {
                    if (counter[1].count == 2) {
                        return .full_house;
                    }
                    return .three_of_a_kind;
                }
                return .one_pair;
            }
            if (counter[0].count == 5) {
                return .five_of_a_kind;
            }
            if (counter[0].count == 4) {
                return .four_of_a_kind;
            }
            if (counter[0].count == 3) {
                if (counter[1].count == 2) {
                    return .full_house;
                }
                return .three_of_a_kind;
            }
            if (counter[0].count == 2) {
                if (counter[1].count == 2) {
                    return .two_pair;
                }
                return .one_pair;
            }
            return .high_card;
        }

        fn getPos(self: *Hand, use_joker: bool) !usize {
            var pos: usize = 0;

            const kind = try self.getKind(use_joker);
            pos += @intFromEnum(kind);

            for (0..HAND_CARDS) |p| {
                pos *= 16;
                pos += self.cards[p].rankValue(use_joker);
            }
            return pos;
        }
    };

    use_joker: bool,
    hands: std.ArrayList(Hand),

    pub fn init(allocator: Allocator, use_joker: bool) Game {
        var self = Game{
            .use_joker = use_joker,
            .hands = std.ArrayList(Hand).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Game) void {
        self.hands.deinit();
    }

    pub fn addLine(self: *Game, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        const hand_str = it.next().?;
        const bid_str = it.next().?;
        var h = Hand.init();
        for (hand_str) |c| {
            try h.addCard(c);
        }
        h.bid = try std.fmt.parseUnsigned(usize, bid_str, 10);
        try self.hands.append(h);
    }

    pub fn show(self: Game) void {
        std.debug.print("Game with {} hands\n", .{self.hands.items.len});
        for (self.hands.items) |h| {
            std.debug.print("  {} ", .{h.pos});
            for (h.cards) |c| {
                std.debug.print("{c}", .{c.char});
            }
            std.debug.print(" {}\n", .{h.bid});
        }
    }

    pub fn getTotalWinnings(self: *Game) !usize {
        for (self.hands.items) |*h| {
            try h.computePos(self.use_joker);
        }
        std.sort.heap(Hand, self.hands.items, {}, Hand.lessThan);
        var sum: usize = 0;
        for (self.hands.items, 1..) |h, p| {
            const prod = p * h.bid;
            sum += prod;
        }
        return sum;
    }
};

test "sample part 1" {
    const data =
        \\32T3K 765
        \\T55J5 684
        \\KK677 28
        \\KTJJT 220
        \\QQQJA 483
    ;

    var game = Game.init(std.testing.allocator, false);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }

    const winning = try game.getTotalWinnings();
    // game.show();
    const expected = @as(usize, 6440);
    try testing.expectEqual(expected, winning);
}

test "check part 2" {
    var h = Game.Hand.initFull("QJJQ2");
    try testing.expectEqual(Game.Kind.four_of_a_kind, try h.getKind(true));

    var h1 = Game.Hand.initFull("JKKK2");
    try testing.expectEqual(Game.Kind.four_of_a_kind, try h1.getKind(true));
    var h2 = Game.Hand.initFull("QQQQ2");
    try testing.expectEqual(Game.Kind.four_of_a_kind, try h2.getKind(true));

    try testing.expect(try h1.getPos(true) < try h2.getPos(true));
}

test "sample part 2" {
    const data =
        \\32T3K 765
        \\T55J5 684
        \\KK677 28
        \\KTJJT 220
        \\QQQJA 483
    ;

    var game = Game.init(std.testing.allocator, true);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }

    const winning = try game.getTotalWinnings();
    // game.show();
    const expected = @as(usize, 5905);
    try testing.expectEqual(expected, winning);
}
