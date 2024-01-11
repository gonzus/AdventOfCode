const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Game = struct {
    const StringId = StringTable.StringId;
    const INFINITY = std.math.maxInt(usize);

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

    const Effect = struct {
        lasts: usize,
        remaining: usize,
        damage: usize,
        armor: usize,
        mana: usize,

        pub fn init(lasts: usize, damage: usize, armor: usize, mana: usize) Effect {
            return Effect{
                .lasts = lasts,
                .remaining = 0,
                .damage = damage,
                .armor = armor,
                .mana = mana,
            };
        }
    };

    const Spell = struct {
        name: StringId,
        mana: usize,
        damage: usize,
        healing: usize,
        effect: ?Effect,

        pub fn init(name: StringId, mana: usize, damage: usize, healing: usize) Spell {
            return Spell{
                .name = name,
                .mana = mana,
                .damage = damage,
                .healing = healing,
                .effect = null,
            };
        }
    };

    const Stats = struct {
        mana: usize,
        hit: usize,
        damage: usize,
        armor: usize,

        pub fn init(mana: usize, hit: usize, damage: usize, armor: usize) Stats {
            return Stats{
                .mana = mana,
                .hit = hit,
                .damage = damage,
                .armor = armor,
            };
        }

        pub fn dealDamage(self: *Stats, damage: usize) void {
            self.hit = if (self.hit > damage) self.hit - damage else 0;
        }
    };

    const State = struct {
        spells: std.ArrayList(Spell),
        stats: [PlayerSize]Stats,

        pub fn init(allocator: Allocator) State {
            return State{
                .spells = std.ArrayList(Spell).init(allocator),
                .stats = undefined,
            };
        }

        pub fn deinit(self: *State) void {
            self.spells.deinit();
        }

        pub fn clone(self: State) !State {
            return State{
                .spells = try self.spells.clone(),
                .stats = self.stats,
            };
        }

        pub fn copy(self: *State, other: State) void {
            self.stats = other.stats;
            for (self.spells.items, other.spells.items) |*s, o| {
                s.* = o;
            }
        }
    };

    allocator: Allocator,
    hard: bool,
    strtab: StringTable,
    state: State,
    best: usize,

    pub fn init(allocator: Allocator, hard: bool) !Game {
        var self = Game{
            .allocator = allocator,
            .hard = hard,
            .strtab = StringTable.init(allocator),
            .state = State.init(allocator),
            .best = INFINITY,
        };
        try self.addSpells();
        return self;
    }

    pub fn deinit(self: *Game) void {
        self.state.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Game, line: []const u8) !void {
        const p = @intFromEnum(Player.boss);
        var it = std.mem.tokenizeSequence(u8, line, ": ");
        const what = it.next().?;
        const num = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        if (std.mem.eql(u8, what, "Hit Points")) {
            self.state.stats[p].hit = num;
            return;
        }
        if (std.mem.eql(u8, what, "Damage")) {
            self.state.stats[p].damage = num;
            return;
        }
        if (std.mem.eql(u8, what, "Armor")) {
            self.state.stats[p].armor = num;
            return;
        }
        return error.InvalidData;
    }

    pub fn setStats(self: *Game, player: Player, mana: usize, hit: usize, damage: usize, armor: usize) !void {
        const p = @intFromEnum(player);
        self.state.stats[p] = Stats.init(mana, hit, damage, armor);
    }

    pub fn findLeastAmountOfMana(self: *Game) !usize {
        try self.walkGame(0, Player.human);
        return self.best;
    }

    fn walkGame(self: *Game, spent: usize, turn: Player) !void {
        if (spent >= self.best) return;

        const human = &self.state.stats[@intFromEnum(Player.human)];
        const boss = &self.state.stats[@intFromEnum(Player.boss)];

        if (self.hard and turn == .human) {
            human.hit -= 1;
            if (human.hit == 0) {
                return;
            }
        }

        // deal outstanding effects
        for (self.state.spells.items) |*spell| {
            if (spell.effect) |*e| {
                if (e.remaining == 0) continue;

                boss.dealDamage(e.damage);
                human.mana += e.mana;
                e.remaining -= 1;
                if (e.remaining == 0) {
                    human.armor -= e.armor;
                }
            }
        }
        if (boss.hit == 0) {
            self.best = @min(self.best, spent);
            return;
        }

        switch (turn) {
            .human => {
                var state = try self.state.clone();
                defer state.deinit();

                for (self.state.spells.items) |*spell| {
                    if (spell.mana > human.mana) continue;

                    if (spell.effect) |*e| {
                        if (e.remaining > 0) continue;

                        e.remaining = e.lasts;
                        human.armor += e.armor;
                    }

                    human.mana -= spell.mana;
                    human.hit += spell.healing;
                    boss.dealDamage(spell.damage);

                    const total_spent = spent + spell.mana;
                    if (boss.hit == 0) {
                        self.best = @min(self.best, total_spent);
                    } else {
                        try self.walkGame(total_spent, turn.other());
                    }

                    self.state.copy(state);
                }
            },
            .boss => {
                const damage = if (boss.damage > human.armor) boss.damage - human.armor else 1;
                human.dealDamage(damage);
                if (human.hit == 0) {
                    return;
                }
                try self.walkGame(spent, turn.other());
            },
        }
    }

    fn addSpells(self: *Game) !void {
        try self.addSpell("Magic Missile", 53, 4, 0, null);
        try self.addSpell("Drain", 73, 2, 2, null);
        {
            const effect = Effect.init(6, 0, 7, 0);
            try self.addSpell("Shield", 113, 0, 0, effect);
        }
        {
            const effect = Effect.init(6, 3, 0, 0);
            try self.addSpell("Poison", 173, 0, 0, effect);
        }
        {
            const effect = Effect.init(5, 0, 0, 101);
            try self.addSpell("Recharge", 229, 0, 0, effect);
        }
    }

    fn addSpell(
        self: *Game,
        name: []const u8,
        mana: usize,
        damage: usize,
        healing: usize,
        effect: ?Effect,
    ) !void {
        const id = try self.strtab.add(name);
        var spell = Spell.init(id, mana, damage, healing);
        if (effect) |e| {
            spell.effect = e;
        }
        try self.state.spells.append(spell);
    }
};

test "sample part 1 first" {
    var game = try Game.init(std.testing.allocator, false);
    defer game.deinit();

    try game.setStats(.human, 250, 10, 0, 0);
    try game.setStats(.boss, 0, 13, 8, 0);
    const spent = try game.findLeastAmountOfMana();
    const expected: usize = 173 + 53;
    try testing.expectEqual(expected, spent);
}

test "sample part 1 second" {
    var game = try Game.init(std.testing.allocator, false);
    defer game.deinit();

    try game.setStats(.human, 250, 10, 0, 0);
    try game.setStats(.boss, 0, 14, 8, 0);
    const spent = try game.findLeastAmountOfMana();
    const expected: usize = 229 + 113 + 73 + 173 + 53;
    try testing.expectEqual(expected, spent);
}

test "sample part 2 first" {
    var game = try Game.init(std.testing.allocator, true);
    defer game.deinit();

    try game.setStats(.human, 250, 10, 0, 0);
    try game.setStats(.boss, 0, 13, 8, 0);
    const spent = try game.findLeastAmountOfMana();
    const expected: usize = Game.INFINITY;
    try testing.expectEqual(expected, spent);
}

test "sample part 2 second" {
    var game = try Game.init(std.testing.allocator, true);
    defer game.deinit();

    try game.setStats(.human, 250, 10, 0, 0);
    try game.setStats(.boss, 0, 14, 8, 0);
    const spent = try game.findLeastAmountOfMana();
    const expected: usize = Game.INFINITY;
    try testing.expectEqual(expected, spent);
}
