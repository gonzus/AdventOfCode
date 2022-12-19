const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;
const RndGen = std.rand.DefaultPrng;

pub const Factory = struct {
    // yes: I, gonzo, am ashamed of this
    const MAGIC_ITERATIONS_FOR_PART_1 = 10_000;
    const MAGIC_ITERATIONS_FOR_PART_2 = 100_000;

    const Material = enum {
        ore,
        clay,
        obsidian,
        geode,

        pub fn parse(what: []const u8) Material {
            if (std.mem.eql(u8, what, "ore")) return .ore;
            if (std.mem.eql(u8, what, "clay")) return .clay;
            if (std.mem.eql(u8, what, "obsidian")) return .obsidian;
            if (std.mem.eql(u8, what, "geode")) return .geode;
            unreachable;
        }
    };

    const Requirement = struct {
        materials: std.AutoHashMap(Material, usize),

        pub fn init(allocator: Allocator) Requirement {
            var self = Requirement{
                .materials = std.AutoHashMap(Material, usize).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Requirement) void {
            self.materials.deinit();
        }
    };

    const Blueprint = struct {
        id: usize,
        requirements: std.AutoHashMap(Material, Requirement),

        pub fn init(allocator: Allocator, id: usize) Blueprint {
            var self = Blueprint{
                .id = id,
                .requirements = std.AutoHashMap(Material, Requirement).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Blueprint) void {
            var it = self.requirements.iterator();
            while (it.next()) |entry| {
                entry.value_ptr.*.deinit();
            }
            self.requirements.deinit();
        }
    };

    const Inventory = struct {
        items: std.AutoHashMap(Material, usize),
        valid: bool,

        pub fn init(allocator: Allocator) Inventory {
            var self = Inventory{
                .items = std.AutoHashMap(Material, usize).init(allocator),
                .valid = true,
            };
            return self;
        }

        pub fn deinit(self: *Inventory) void {
            if (!self.valid) return;
            self.items.deinit();
        }

        pub fn get(self: Inventory, material: Material) usize {
            return self.items.get(material) orelse 0;
        }

        pub fn add(self: *Inventory, material: Material, amount: usize) !void {
            const result = try self.items.getOrPut(material);
            if (!result.found_existing) {
                result.value_ptr.* = 0;
            }
            result.value_ptr.* += amount;
        }

        pub fn remove(self: *Inventory, material: Material, amount: usize) !void {
            const result = try self.items.getOrPut(material);
            if (!result.found_existing) {
                result.value_ptr.* = 0;
            }
            result.value_ptr.* -= amount;
        }

        pub fn clear(self: *Inventory) void {
            self.items.clearRetainingCapacity();
        }

        pub fn clone(self: Inventory) !Inventory {
            return Inventory{ .items = try self.items.clone(), .valid = true };
        }

        pub fn restore(self: *Inventory, other: *Inventory) void {
            self.items.deinit();
            self.items = other.items;
            other.valid = false;
        }
    };

    allocator: Allocator,
    blueprints: std.AutoHashMap(usize, Blueprint),
    robots: Inventory,
    materials: Inventory,
    building: Inventory,
    rnd: RndGen,

    pub fn init(allocator: Allocator) Factory {
        var self = Factory{
            .allocator = allocator,
            .blueprints = std.AutoHashMap(usize, Blueprint).init(allocator),
            .robots = Inventory.init(allocator),
            .materials = Inventory.init(allocator),
            .building = Inventory.init(allocator),
            .rnd = RndGen.init(0),

        };
        return self;
    }

    pub fn deinit(self: *Factory) void {
        self.building.deinit();
        self.materials.deinit();
        self.robots.deinit();
        var it = self.blueprints.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.blueprints.deinit();
    }

    pub fn add_line(self: *Factory, line: []const u8) !void {
        var itl = std.mem.tokenize(u8, line, ":");

        var itb = std.mem.tokenize(u8, itl.next().?, " "); // Blueprint: X
        _ = itb.next().?; // Blueprint
        const bn = try std.fmt.parseInt(usize, itb.next().?, 10); // X
        var blueprint = Blueprint.init(self.allocator, bn);

        var itr = std.mem.tokenize(u8, itl.next().?, "."); // Each xxx robot...
        while (itr.next()) |str_robot| {
            var in_materials = false;
            var itm = std.mem.tokenize(u8, str_robot, " "); // Each xxx robot...
            var robot: Material = undefined;
            var requirement = Requirement.init(self.allocator);
            while (true) {
                if (itm.peek()) |_| {} else break;
                if (!in_materials) {
                    _ = itm.next().?; // Each
                    robot = Material.parse(itm.next().?);
                    _ = itm.next().?; // robot
                    in_materials = true;
                } else {
                    _ = itm.next().?; // costs / and
                    const amount = try std.fmt.parseInt(usize, itm.next().?, 10); // X
                    const material = Material.parse(itm.next().?);
                    try requirement.materials.put(material, amount);
                }
            }
            try blueprint.requirements.put(robot, requirement);
        }
        try self.blueprints.put(bn, blueprint);
    }

    pub fn show(self: Factory) void {
        std.debug.print("-- Blueprints: {} --------\n", .{self.blueprints.count()});
        var itb = self.blueprints.iterator();
        while (itb.next()) |eb| {
            const nb = eb.key_ptr.*;
            const blueprint = eb.value_ptr.*;
            std.debug.print("Blueprint {}\n", .{nb});
            var itr = blueprint.requirements.iterator();
            while (itr.next()) |er| {
                const robot = er.key_ptr.*;
                const requirement = er.value_ptr.*;
                std.debug.print("  Requirements for robot building {}\n", .{robot});
                var itm = requirement.materials.iterator();
                while (itm.next()) |em| {
                    const material = em.key_ptr.*;
                    const amount = em.value_ptr.*;
                    std.debug.print("    {} => {}\n", .{material, amount});
                }
            }
        }
    }

    pub fn can_build_robot(self: Factory, robot: Material, blueprint: Blueprint) bool {
        const r = blueprint.requirements.get(robot);
        if (r) |requirement| {
            var itm = requirement.materials.iterator();
            while (itm.next()) |em| {
                const material = em.key_ptr.*;
                const needed = em.value_ptr.*;
                const got = self.materials.get(material);
                if (needed > got) return false;
            }
            return true;
        } else {
            return false;
        }
    }

    pub fn build_robot(self: *Factory, robot: Material, blueprint: Blueprint) !void {
        const r = blueprint.requirements.get(robot);
        if (r) |requirement| {
            var itm = requirement.materials.iterator();
            while (itm.next()) |em| {
                const material = em.key_ptr.*;
                const needed = em.value_ptr.*;
                try self.materials.remove(material, needed);
            }
            try self.building.add(robot, 1);
        }
    }

    fn find_best_geode_strategy(self: *Factory, part: usize, blueprint: Blueprint, left: usize) !usize {
        if (left <= 0) {
            const geodes = self.materials.get(.geode);
            return geodes;
        }

        var robots = try self.robots.clone();
        defer self.robots.restore(&robots);
        var materials = try self.materials.clone();
        defer self.materials.restore(&materials);

        const BuildConfig = struct {
            robot: Material,
            needed: usize,
            chance: usize,
        };
        const configs = [_]BuildConfig {
            BuildConfig{ .robot = .geode   , .needed = 1, .chance =  if (part == 1) 90 else 100 },
            BuildConfig{ .robot = .obsidian, .needed = 2, .chance =  if (part == 1) 50 else  90 },
            BuildConfig{ .robot = .clay    , .needed = 3, .chance =  if (part == 1) 80 else  50 },
            BuildConfig{ .robot = .ore     , .needed = 3, .chance =  if (part == 1) 60 else 100 },
        };

        // choose new robots to build and start building
        self.building.clear();
        for (configs) |config| {
            if (left <= config.needed) continue;
            const r = self.rnd.random().int(u32) % 100;
            if (r > config.chance) continue;
            if (!self.can_build_robot(config.robot, blueprint)) continue;

            try self.build_robot(config.robot, blueprint);
            break;
        }

        // collect material from active robots
        var ita = self.robots.items.iterator();
        while (ita.next()) |er| {
            const amount = er.value_ptr.*;
            if (amount <= 0) continue;
            const material = er.key_ptr.*;
            try self.materials.add(material, amount);
        }

        // finish robots that were being built
        var itb = self.building.items.iterator();
        while (itb.next()) |eb| {
            const amount = eb.value_ptr.*;
            if (amount <= 0) continue;
            eb.value_ptr.* = 0;
            const robot = eb.key_ptr.*;
            try self.robots.add(robot, amount);
        }

        return try self.find_best_geode_strategy(part, blueprint, left - 1);
    }

    fn max_geodes(self: *Factory, part: usize, blueprint: Blueprint, left: usize, iterations: usize) !usize {
        var best: usize = 0;

        var tries: usize = 0;
        while (tries < iterations) : (tries += 1) {
            self.robots.clear();
            self.materials.clear();
            self.building.clear();

            try self.robots.add(.ore, 1);

            const geodes = try self.find_best_geode_strategy(part, blueprint, left);
            if (best < geodes) best = geodes;
        }
        // std.debug.print("<{}> BUILT {} GEODES (after {} iterations)\n", .{blueprint.id, best, iterations});
        return best;
    }

    pub fn sum_quality_levels(self: *Factory, left: usize) !usize {
        var sum: usize = 0;
        var itb = self.blueprints.iterator();
        while (itb.next()) |eb| {
            const nb = eb.key_ptr.*;
            const blueprint = eb.value_ptr.*;
            const ng = try self.max_geodes(1, blueprint, left, MAGIC_ITERATIONS_FOR_PART_1);
            sum += nb * ng;
        }
        return sum;
    }

    pub fn multiply_geodes(self: *Factory, left: usize, top: usize) !usize {
        var product: usize = 1;
        var id: usize = 1;
        while (id <= top) : (id += 1) {
            const bp = self.blueprints.get(id);
            if (bp) |blueprint| {
                const ng = try self.max_geodes(2, blueprint, left, MAGIC_ITERATIONS_FOR_PART_2);
                product *= ng;
            }
        }
        return product;
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\Blueprint 1: Each ore robot costs 4 ore. Each clay robot costs 2 ore. Each obsidian robot costs 3 ore and 14 clay. Each geode robot costs 2 ore and 7 obsidian.
        \\Blueprint 2: Each ore robot costs 2 ore. Each clay robot costs 3 ore. Each obsidian robot costs 3 ore and 8 clay. Each geode robot costs 3 ore and 12 obsidian.
    ;

    var factory = Factory.init(std.testing.allocator);
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try factory.add_line(line);
    }
    // factory.show();

    const sql = try factory.sum_quality_levels(24);
    try testing.expectEqual(@as(usize, 33), sql);
}

test "sample part 2" {
    const data: []const u8 =
        \\Blueprint 1: Each ore robot costs 4 ore. Each clay robot costs 2 ore. Each obsidian robot costs 3 ore and 14 clay. Each geode robot costs 2 ore and 7 obsidian.
        \\Blueprint 2: Each ore robot costs 2 ore. Each clay robot costs 3 ore. Each obsidian robot costs 3 ore and 8 clay. Each geode robot costs 3 ore and 12 obsidian.
    ;

    var factory = Factory.init(std.testing.allocator);
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try factory.add_line(line);
    }
    // factory.show();

    const product = try factory.multiply_geodes(32, 2);
    try testing.expectEqual(@as(usize, 56*62), product);
}
