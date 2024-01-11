const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Game = struct {
    const StringId = StringTable.StringId;

    const Player = enum {
        human,
        boss,

        pub fn other(self: Player) Player {
            return switch (self) {
                .human => .boss,
                .boss => .human,
            };
        }
    };
    const PlayerSize = std.meta.tags(Player).len;

    const Kind = enum {
        weapon,
        armor,
        ring,

        pub fn min(self: Kind) usize {
            return switch (self) {
                .weapon => 1,
                .armor => 0,
                .ring => 0,
            };
        }

        pub fn max(self: Kind) usize {
            return switch (self) {
                .weapon => 1,
                .armor => 1,
                .ring => 2,
            };
        }
    };
    const KindSize = std.meta.tags(Kind).len;

    const Stats = struct {
        hit: usize,
        damage: usize,
        armor: usize,

        pub fn init(hit: usize, damage: usize, armor: usize) Stats {
            return Stats{ .hit = hit, .damage = damage, .armor = armor };
        }
    };

    const Item = struct {
        kind: Kind,
        name: StringId,
        cost: usize,
        damage: usize,
        armor: usize,

        pub fn init(kind: Kind, name: StringId, cost: usize, damage: usize, armor: usize) Item {
            return Item{
                .kind = kind,
                .name = name,
                .cost = cost,
                .damage = damage,
                .armor = armor,
            };
        }
    };

    allocator: Allocator,
    strtab: StringTable,
    items: std.ArrayList(Item),
    stats: [PlayerSize]Stats,
    saved: [PlayerSize]Stats,
    best: usize,

    pub fn init(allocator: Allocator) !Game {
        var self = Game{
            .allocator = allocator,
            .strtab = StringTable.init(allocator),
            .items = std.ArrayList(Item).init(allocator),
            .stats = undefined,
            .saved = undefined,
            .best = undefined,
        };
        try self.addItems();
        return self;
    }

    pub fn deinit(self: *Game) void {
        self.items.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Game, line: []const u8) !void {
        const p = @intFromEnum(Player.boss);
        var it = std.mem.tokenizeSequence(u8, line, ": ");
        const what = it.next().?;
        const num = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        if (std.mem.eql(u8, what, "Hit Points")) {
            self.stats[p].hit = num;
            return;
        }
        if (std.mem.eql(u8, what, "Damage")) {
            self.stats[p].damage = num;
            return;
        }
        if (std.mem.eql(u8, what, "Armor")) {
            self.stats[p].armor = num;
            return;
        }
        return error.InvalidData;
    }

    pub fn setStats(self: *Game, player: Player, hit: usize, damage: usize, armor: usize) !void {
        const p = @intFromEnum(player);
        self.stats[p] = Stats.init(hit, damage, armor);
    }

    pub fn findLeastAmountOfGold(self: *Game) !usize {
        var used = [_]usize{0} ** KindSize;
        self.best = std.math.maxInt(usize);
        try self.walkCombinations(0, &used, 0, true);
        return self.best;
    }

    pub fn findMostAmountOfGold(self: *Game) !usize {
        var used = [_]usize{0} ** KindSize;
        self.best = std.math.minInt(usize);
        try self.walkCombinations(0, &used, 0, false);
        return self.best;
    }

    fn addItems(self: *Game) !void {
        try self.addItem(.weapon, "Dagger", 8, 4, 0);
        try self.addItem(.weapon, "Shortsword", 10, 5, 0);
        try self.addItem(.weapon, "Warhammer", 25, 6, 0);
        try self.addItem(.weapon, "Longsword", 40, 7, 0);
        try self.addItem(.weapon, "Greataxe", 74, 8, 0);

        try self.addItem(.armor, "Leather", 13, 0, 1);
        try self.addItem(.armor, "Chainmail", 31, 0, 2);
        try self.addItem(.armor, "Splintmail", 53, 0, 3);
        try self.addItem(.armor, "Bandedmail", 75, 0, 4);
        try self.addItem(.armor, "Platemail", 102, 0, 5);

        try self.addItem(.ring, "Damage +1", 25, 1, 0);
        try self.addItem(.ring, "Damage +2", 50, 2, 0);
        try self.addItem(.ring, "Damage +3", 100, 3, 0);
        try self.addItem(.ring, "Defense +1", 20, 0, 1);
        try self.addItem(.ring, "Defense +2", 40, 0, 2);
        try self.addItem(.ring, "Defense +3", 80, 0, 3);
    }

    fn addItem(self: *Game, kind: Kind, name: []const u8, cost: usize, damage: usize, armor: usize) !void {
        const id = try self.strtab.add(name);
        try self.items.append(Item.init(kind, id, cost, damage, armor));
    }

    fn playUntilWinning(self: *Game) Player {
        var turn = Player.human;
        while (true) {
            const won = self.playOneRound(turn);
            if (won) break;
            turn = turn.other();
        }
        return turn;
    }

    fn playOneRound(self: *Game, player: Player) bool {
        const p = @intFromEnum(player);
        const attacker = self.stats[p];
        const defender = &self.stats[1 - p];
        const damage = if (attacker.damage > defender.*.armor) attacker.damage - defender.*.armor else 1;
        if (defender.*.hit > damage) {
            defender.*.hit -= damage;
        } else {
            defender.*.hit = 0;
        }
        return defender.*.hit == 0;
    }

    fn walkCombinations(self: *Game, gold_spent: usize, used: []usize, pos: usize, least: bool) !void {
        if (pos >= self.items.items.len) {
            var valid = true;
            for (std.meta.tags(Kind)) |kind| {
                const p = @intFromEnum(kind);
                if (used[p] < kind.min()) {
                    valid = false;
                    break;
                }
            }
            if (valid) {
                self.saveStats();
                defer self.restoreStats();

                const winner = self.playUntilWinning();
                if (least) {
                    if (winner == .human) {
                        if (self.best > gold_spent) {
                            self.best = gold_spent;
                        }
                    }
                } else {
                    if (winner == .boss) {
                        if (self.best < gold_spent) {
                            self.best = gold_spent;
                        }
                    }
                }
            }
            return;
        }

        const item = self.items.items[pos];
        const k = @intFromEnum(item.kind);
        const h = @intFromEnum(Player.human);
        if (used[k] < item.kind.max()) {
            // still have not reached max for this kind of item
            // try buying this item
            used[k] += 1;
            self.stats[h].damage += item.damage;
            self.stats[h].armor += item.armor;
            try self.walkCombinations(gold_spent + item.cost, used, pos + 1, least);
            self.stats[h].armor -= item.armor;
            self.stats[h].damage -= item.damage;
            used[k] -= 1;
        }
        // try not buying this item
        try self.walkCombinations(gold_spent, used, pos + 1, least);
    }

    fn saveStats(self: *Game) void {
        self.saved = self.stats;
    }

    fn restoreStats(self: *Game) void {
        self.stats = self.saved;
    }
};

test "sample part 1" {
    var game = try Game.init(std.testing.allocator);
    defer game.deinit();

    try game.setStats(.human, 8, 5, 5);
    try game.setStats(.boss, 12, 7, 2);
    const winner = game.playUntilWinning();
    const expected = Game.Player.human;
    try testing.expectEqual(expected, winner);
}
