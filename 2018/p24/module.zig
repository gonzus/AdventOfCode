const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Simulator = struct {
    const StringId = StringTable.StringId;
    const INVALID_STRING = std.math.maxInt(StringId);
    const Set = std.AutoHashMap(StringId, void);

    const Team = enum {
        immune,
        infection,

        pub fn format(
            t: Team,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("{s}", .{@tagName(t)});
        }
    };

    const Group = struct {
        team: Team,
        size: usize,
        dead: usize,
        hit_points: usize,
        weaknesses: Set,
        immunities: Set,
        attack_damage: usize,
        attack_type: StringId,
        initiative: usize,
        boost: usize,
        strtab: *StringTable,

        pub fn init(allocator: Allocator, team: Team, strtab: *StringTable) Group {
            return .{
                .team = team,
                .size = 0,
                .dead = 0,
                .hit_points = 0,
                .weaknesses = Set.init(allocator),
                .immunities = Set.init(allocator),
                .attack_damage = 0,
                .attack_type = INVALID_STRING,
                .initiative = 0,
                .boost = 0,
                .strtab = strtab,
            };
        }

        pub fn deinit(self: *Group) void {
            self.immunities.deinit();
            self.weaknesses.deinit();
        }

        pub fn reset(self: *Group) void {
            self.dead = 0;
        }

        pub fn countSurvivors(self: Group) usize {
            return self.size - self.dead;
        }

        pub fn isDead(self: Group) bool {
            return self.countSurvivors() == 0;
        }

        pub fn attackDamage(self: Group) usize {
            return self.attack_damage + self.boost;
        }

        pub fn effectivePower(self: Group) usize {
            return self.countSurvivors() * self.attackDamage();
        }

        pub fn damageCausedTo(self: Group, other: Group) usize {
            if (other.immunities.contains(self.attack_type)) return 0;
            var factor: usize = 1;
            if (other.weaknesses.contains(self.attack_type)) factor = 2;
            return factor * self.effectivePower();
        }

        pub fn applyDamage(self: *Group, damage: usize) void {
            if (self.countSurvivors() <= damage) {
                self.dead = self.size; // kill unit
            } else {
                self.dead += damage; // apply damage
            }
        }

        fn cmpByEffectivePowerAndInitiativeDesc(simulator: *Simulator, l: usize, r: usize) bool {
            const gl = simulator.groups.items[l];
            const gr = simulator.groups.items[r];

            const epl = gl.effectivePower();
            const epr = gr.effectivePower();
            if (epl < epr) return false;
            if (epl > epr) return true;

            if (gl.initiative < gr.initiative) return false;
            if (gl.initiative > gr.initiative) return true;

            return false;
        }

        fn cmpByInitiativeDesc(simulator: *Simulator, l: usize, r: usize) bool {
            const gl = simulator.groups.items[l];
            const gr = simulator.groups.items[r];

            if (gl.initiative < gr.initiative) return false;
            if (gl.initiative > gr.initiative) return true;

            return false;
        }

        pub fn format(
            g: Group,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("Group[team={},size={},hit_points={},attack_damage={},attack_type={s},initiative={}", .{
                g.team,
                g.countSurvivors(),
                g.hit_points,
                g.attackDamage(),
                g.strtab.*.get_str(g.attack_type) orelse "*INVALID*",
                g.initiative,
            });
            try formatSet(g.weaknesses, "weaknesses", g.strtab, writer);
            try formatSet(g.immunities, "immunities", g.strtab, writer);
            _ = try writer.print("]", .{});
        }

        fn formatSet(set: Set, label: []const u8, strtab: *StringTable, writer: anytype) !void {
            _ = try writer.print(",{s}=<", .{label});
            var sep: []const u8 = "";
            var it = set.keyIterator();
            while (it.next()) |id| {
                _ = try writer.print("{s}{s}", .{ sep, strtab.*.get_str(id.*) orelse "*INVALID" });
                sep = ",";
            }
            _ = try writer.print(">", .{});
        }
    };

    allocator: Allocator,
    strtab: StringTable,
    groups: std.ArrayList(Group),
    team: Team,
    immune_cnt: usize,
    infection_cnt: usize,
    winning_team: Team,

    pub fn init(allocator: Allocator) Simulator {
        return .{
            .allocator = allocator,
            .strtab = StringTable.init(allocator),
            .groups = std.ArrayList(Group).init(allocator),
            .team = undefined,
            .immune_cnt = 0,
            .infection_cnt = 0,
            .winning_team = undefined,
        };
    }

    pub fn deinit(self: *Simulator) void {
        for (self.groups.items) |*g| {
            g.*.deinit();
        }
        self.groups.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Simulator, line: []const u8) !void {
        if (line.len == 0) return;
        if (std.mem.eql(u8, line, "Immune System:")) {
            self.team = .immune;
            return;
        }
        if (std.mem.eql(u8, line, "Infection:")) {
            self.team = .infection;
            return;
        }
        var group = Group.init(self.allocator, self.team, &self.strtab);
        var it = std.mem.tokenizeAny(u8, line, " (),;");
        group.size = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        _ = it.next();
        _ = it.next();
        _ = it.next();
        group.hit_points = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        _ = it.next();
        _ = it.next();
        var chunk = it.next().?;
        while (true) {
            if (std.mem.eql(u8, chunk, "with")) break;
            var set: ?*Set = null;
            if (std.mem.eql(u8, chunk, "weak")) set = &group.weaknesses;
            if (std.mem.eql(u8, chunk, "immune")) set = &group.immunities;
            if (set) |s| {
                while (true) {
                    chunk = it.next().?;
                    if (std.mem.eql(u8, chunk, "to")) continue;
                    if (std.mem.eql(u8, chunk, "weak")) break;
                    if (std.mem.eql(u8, chunk, "immune")) break;
                    if (std.mem.eql(u8, chunk, "with")) break;
                    const id = try self.strtab.add(chunk);
                    _ = try s.getOrPut(id);
                }
            } else {
                return error.InvalidSpec;
            }
        }
        _ = it.next();
        _ = it.next();
        _ = it.next();
        _ = it.next();
        group.attack_damage = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        chunk = it.next().?;
        group.attack_type = try self.strtab.add(chunk);
        _ = it.next();
        _ = it.next();
        _ = it.next();
        group.initiative = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        try self.groups.append(group);
    }

    pub fn show(self: Simulator) void {
        std.debug.print("Simulator with {} groups\n", .{self.groups.items.len});
        for (self.groups.items) |g| {
            std.debug.print("  {}\n", .{g});
        }
    }

    pub fn getCountOfWinningUnits(self: *Simulator) !usize {
        try self.run(0);
        return if (self.winning_team == .immune) self.immune_cnt else self.infection_cnt;
    }

    pub fn getCountforImmuneWithSmallestBoost(self: *Simulator) !usize {
        var hi: usize = 1;
        while (true) : (hi *= 2) {
            try self.run(hi);
            if (self.winning_team == .immune) break;
        }

        var count: usize = 0;
        var lo: usize = 1;
        while (lo != hi) {
            const boost = (lo + hi) / 2;
            try self.run(boost);
            if (self.winning_team == .immune) {
                hi = boost;
                count = self.immune_cnt;
            } else {
                lo = boost + 1;
            }
        }
        // std.debug.print("BOOST found {}\n", .{hi});
        return count;
    }

    fn computeStats(self: *Simulator) void {
        self.immune_cnt = 0;
        self.infection_cnt = 0;
        var immune_len: usize = 0;
        var infection_len: usize = 0;
        for (self.groups.items) |g| {
            if (g.isDead()) continue;
            switch (g.team) {
                .immune => {
                    immune_len += 1;
                    self.immune_cnt += g.countSurvivors();
                },
                .infection => {
                    infection_len += 1;
                    self.infection_cnt += g.countSurvivors();
                },
            }
        }
        self.winning_team = .infection;
        if (infection_len < immune_len) self.winning_team = .immune;
    }

    fn run(self: *Simulator, boost: usize) !void {
        for (self.groups.items) |*g| {
            g.reset();
            g.boost = switch (g.team) {
                .immune => boost,
                .infection => 0,
            };
        }
        var combatants = std.ArrayList(usize).init(self.allocator);
        defer combatants.deinit();
        var potential = std.AutoHashMap(usize, void).init(self.allocator);
        defer potential.deinit();
        var attacked = std.AutoHashMap(usize, usize).init(self.allocator);
        defer attacked.deinit();

        while (true) {
            potential.clearRetainingCapacity();

            combatants.clearRetainingCapacity();
            for (self.groups.items, 0..) |group, pos| {
                if (group.isDead()) continue;
                try combatants.append(pos);
                _ = try potential.getOrPut(pos);
            }

            // std.debug.print("ROUND with {} combatants\n", .{ combatants.items.len});
            std.sort.heap(usize, combatants.items, self, Group.cmpByEffectivePowerAndInitiativeDesc);

            attacked.clearRetainingCapacity();
            for (combatants.items) |combatant_pos| {
                const group = self.groups.items[combatant_pos];
                if (group.isDead()) continue;
                var max_found = false;
                var max_pos: usize = 0;
                var max_damage: usize = 0;
                var max_power: usize = 0;
                var max_initiative: usize = 0;
                var it = potential.keyIterator();
                while (it.next()) |potential_pos| {
                    const enemy = self.groups.items[potential_pos.*];
                    if (enemy.isDead()) continue;
                    if (enemy.team == group.team) continue;
                    const damage = group.damageCausedTo(enemy);
                    if (damage == 0) continue;
                    const power = enemy.effectivePower();
                    const initiative = enemy.initiative;
                    var change = false;
                    if (!change and max_damage > damage) continue;
                    if (!change and max_damage < damage) change = true;
                    if (!change and max_power > power) continue;
                    if (!change and max_power < power) change = true;
                    if (!change and max_initiative > initiative) continue;
                    if (!change and max_initiative < initiative) change = true;
                    if (!change) continue;

                    max_found = true;
                    max_pos = potential_pos.*;
                    max_damage = damage;
                    max_power = power;
                    max_initiative = initiative;
                }
                if (!max_found) continue;
                try attacked.put(combatant_pos, max_pos);
                _ = potential.remove(max_pos);
            }

            std.sort.heap(usize, combatants.items, self, Group.cmpByInitiativeDesc);
            var damaged = false;
            for (combatants.items) |combatant_pos| {
                const group = self.groups.items[combatant_pos];
                if (group.isDead()) continue;
                if (attacked.get(combatant_pos)) |enemy_pos| {
                    const enemy = &self.groups.items[enemy_pos];
                    const total_damage = group.damageCausedTo(enemy.*);
                    const damage = total_damage / enemy.*.hit_points;
                    if (damage == 0) continue;
                    damaged = true;
                    enemy.*.applyDamage(damage);
                }
            }
            if (!damaged) break;
        }
        self.computeStats();
    }
};

test "sample part 1" {
    const data =
        \\Immune System:
        \\17 units each with 5390 hit points (weak to radiation, bludgeoning) with an attack that does 4507 fire damage at initiative 2
        \\989 units each with 1274 hit points (immune to fire; weak to bludgeoning, slashing) with an attack that does 25 slashing damage at initiative 3
        \\
        \\Infection:
        \\801 units each with 4706 hit points (weak to radiation) with an attack that does 116 bludgeoning damage at initiative 1
        \\4485 units each with 2961 hit points (immune to radiation; weak to fire, cold) with an attack that does 12 slashing damage at initiative 4
    ;

    var simulator = Simulator.init(std.testing.allocator);
    defer simulator.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try simulator.addLine(line);
    }
    // simulator.show();

    const units = try simulator.getCountOfWinningUnits();
    const expected = @as(usize, 5216);
    try testing.expectEqual(expected, units);
}

test "sample part 2" {
    const data =
        \\Immune System:
        \\17 units each with 5390 hit points (weak to radiation, bludgeoning) with an attack that does 4507 fire damage at initiative 2
        \\989 units each with 1274 hit points (immune to fire; weak to bludgeoning, slashing) with an attack that does 25 slashing damage at initiative 3
        \\
        \\Infection:
        \\801 units each with 4706 hit points (weak to radiation) with an attack that does 116 bludgeoning damage at initiative 1
        \\4485 units each with 2961 hit points (immune to radiation; weak to fire, cold) with an attack that does 12 slashing damage at initiative 4
    ;

    var simulator = Simulator.init(std.testing.allocator);
    defer simulator.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try simulator.addLine(line);
    }
    // simulator.show();

    const units = try simulator.getCountforImmuneWithSmallestBoost();
    const expected = @as(usize, 51);
    try testing.expectEqual(expected, units);
}
