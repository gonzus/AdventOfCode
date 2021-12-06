const std = @import("std");
const assert = std.debug.assert;
const allocator = std.testing.allocator;

pub const Factory = struct {
    rules: std.StringHashMap(Rule),
    ore_produced: usize,

    const Rule = struct {
        needed: std.StringHashMap(usize),
        material: []u8,
        amount: usize,

        pub fn init() Rule {
            var self = Rule{
                .needed = std.StringHashMap(usize).init(allocator),
                .material = undefined,
                .amount = 0,
            };
            return self;
        }

        pub fn deinit(self: *Rule) void {
            var it = self.needed.iterator();
            while (it.next()) |needed| {
                allocator.free(needed.key_ptr.*);
            }
            allocator.free(self.material);
            self.needed.deinit();
        }

        pub fn parse(self: *Rule, str: []const u8) void {
            var statel: usize = 0;
            var itl = std.mem.split(u8, str, "=>");
            while (itl.next()) |side| {
                if (statel == 0) {
                    // left hand: needed
                    var itr = std.mem.split(u8, std.mem.trim(u8, side, " "), ",");
                    while (itr.next()) |rule| {
                        var amount: usize = 0;
                        var staten: usize = 0;
                        var itn = std.mem.split(u8, std.mem.trim(u8, rule, " "), " ");
                        while (itn.next()) |data| {
                            if (staten == 0) {
                                amount = std.fmt.parseInt(usize, data, 10) catch unreachable;
                                staten = 1;
                            } else {
                                // std.debug.warn("NEEDED: {} [{}]\n",.{ amount, data});
                                const needed = allocator.alloc(u8, data.len) catch unreachable;
                                std.mem.copy(u8, needed, data);
                                if (self.needed.contains(needed)) {
                                    std.debug.warn("=== DUPLICATE needed [{s}]\n", .{needed});
                                } else {
                                    _ = self.needed.put(needed, amount) catch unreachable;
                                }
                                staten = 0;
                            }
                        }
                    }
                    statel = 1;
                } else {
                    // right hand: produced
                    var amount: usize = 0;
                    var statep: usize = 0;
                    var itp = std.mem.split(u8, std.mem.trim(u8, side, " "), " ");
                    while (itp.next()) |data| {
                        if (statep == 0) {
                            amount = std.fmt.parseInt(usize, data, 10) catch unreachable;
                            statep = 1;
                        } else {
                            // std.debug.warn("PRODUCED: {} [{}]\n",.{ amount, data});
                            self.amount = amount;
                            self.material = allocator.alloc(u8, data.len) catch unreachable;
                            std.mem.copy(u8, self.material, data);
                            statep = 0;
                        }
                    }
                    statel = 0;
                }
            }
        }

        pub fn show(self: Rule) void {
            std.debug.warn("RULE to produce {} of [{}]:\n", .{ self.amount, self.material });
            var it = self.needed.iterator();
            while (it.next()) |needed| {
                std.debug.warn("  NEED {} of [{}]\n", .{ needed.value, needed.key });
            }
        }
    };

    pub fn init() Factory {
        var self = Factory{
            .rules = std.StringHashMap(Rule).init(allocator),
            .ore_produced = 0,
        };
        return self;
    }

    pub fn deinit(self: *Factory) void {
        var it = self.rules.iterator();
        while (it.next()) |rule| {
            rule.value_ptr.*.deinit();
        }
        self.rules.deinit();
    }

    pub fn parse(self: *Factory, str: []const u8) void {
        var rule = Rule.init();
        rule.parse(str);
        self.add_rule(rule);
    }

    pub fn add_rule(self: *Factory, rule: Rule) void {
        const name = rule.material;
        if (self.rules.contains(name)) {
            std.debug.warn("=== DUPLICATE rule for [{s}]\n", .{name});
        } else {
            _ = self.rules.put(name, rule) catch unreachable;
        }
    }

    pub fn show(self: Factory) void {
        std.debug.warn("ALL RULES\n", .{});
        var it = self.rules.iterator();
        while (it.next()) |rule| {
            std.debug.warn("  RULE for [{}]:\n", .{rule.key});
            rule.value.show();
        }
    }

    pub fn ore_needed_for_fuel(self: *Factory, amount: usize) usize {
        var left = std.StringHashMap(usize).init(allocator);
        defer left.deinit();
        self.ore_produced = 0;
        self.ore_needed("FUEL", amount, &left);
        return self.ore_produced;
    }

    fn ore_needed(self: *Factory, material: []const u8, needed: usize, left: *std.StringHashMap(usize)) void {
        var amount_left: usize = 0;
        if (left.contains(material)) {
            amount_left = left.get(material).?;
        }
        var amount_needed: usize = needed;
        if (amount_left >= amount_needed) {
            // std.debug.warn("ENOUGH [{}]: LEFT {}, NEEDED {}\n",.{ material, amount_left, amount_needed});
            amount_left -= amount_needed;
            _ = left.put(material, amount_left) catch unreachable;
            return;
        }

        if (std.mem.eql(u8, material, "ORE")) {
            const produced = amount_needed - amount_left;
            self.ore_produced += produced;
            // std.debug.warn("PRODUCE [{}]: LEFT {}, NEEDED {}, PRODUCED {}, TOTAL {}\n",.{ material, amount_left, amount_needed, produced, self.ore_produced});
            amount_left = 0;
            _ = left.put(material, amount_left) catch unreachable;
            return;
        }

        if (!self.rules.contains(material)) {
            std.debug.warn("=== NO RULE for [{s}]:\n", .{material});
            return;
        }

        if (amount_left > 0) {
            // std.debug.warn("HAVE {} for [{}]\n",.{ amount_left, material});
            amount_needed -= amount_left;
            amount_left = 0;
        }

        const rules = self.rules.get(material).?;
        const can_produce = rules.amount;
        const runs = (amount_needed + can_produce - 1) / can_produce;
        const produced = can_produce * runs;
        amount_left = produced - amount_needed;

        var it = rules.needed.iterator();
        while (it.next()) |rule| {
            // we need X of a product, and have rules to produce Y, which require A of m1, B of m2, etc
            // we will have to run several copies of the rule
            const ingredient_name = rule.key_ptr.*;
            const ingredient_needed = runs * rule.value_ptr.*;
            // std.debug.warn("NEED for {} [{}]: [{}] -- required {}\n",.{ amount_needed, material, ingredient_name, ingredient_needed});
            self.ore_needed(ingredient_name, ingredient_needed, left);
            // std.debug.warn("MADE for {} [{}]: [{}] -- produced {}\n",.{ amount_needed, material, ingredient_name, ingredient_produced});
        }
        _ = left.put(material, amount_left) catch unreachable;
    }

    pub fn fuel_possible(self: *Factory, available_ore: usize) usize {
        // we will do a binary search, need to bracket with two points, one too low and one too high
        const need_for_one = self.ore_needed_for_fuel(1);
        var fuel_lo: usize = @intCast(usize, available_ore / need_for_one); // estimation, will be too small
        // var need_lo = self.ore_needed_for_fuel(fuel_lo);
        // std.debug.warn("LO {} {} -- {}\n",.{ fuel_lo, need_lo, @intCast(i64, available_ore - need_lo}));

        var fuel_hi: usize = fuel_lo * 2; // estimation
        var need_hi: usize = 0;
        while (true) {
            need_hi = self.ore_needed_for_fuel(fuel_hi);
            if (need_hi >= available_ore) break;
            fuel_hi *= 2;
        }
        // std.debug.warn("HI {} {} -- {}\n",.{ fuel_hi, need_hi, @intCast(i64, available_ore) - @intCast(i64, need_hi)});

        // now a classic binary search
        var j: usize = 0;
        while (true) : (j += 1) {
            const fuel_half: usize = (fuel_lo + fuel_hi) / 2;
            const need_half = self.ore_needed_for_fuel(fuel_half);
            // std.debug.warn("#{}: {} {} -> {} {} -- {}\n",.{ j, fuel_lo, fuel_hi, fuel_half, need_half, @intCast(i64, available_ore) - @intCast(i64, need_half)});
            if (fuel_hi == fuel_half or fuel_lo == fuel_half) break;
            if (need_half > available_ore) {
                fuel_hi = fuel_half;
            } else {
                fuel_lo = fuel_half;
            }
        }
        return fuel_lo;
    }
};

test "ore needed 1" {
    const data =
        \\10 ORE => 10 A
        \\1 ORE => 1 B
        \\7 A, 1 B => 1 C
        \\7 A, 1 C => 1 D
        \\7 A, 1 D => 1 E
        \\7 A, 1 E => 1 FUEL
    ;

    var factory = Factory.init();
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        factory.parse(line);
    }
    const needed = factory.ore_needed_for_fuel(1);
    // std.debug.warn("NEEDED {} ore\n",.{ needed});
    assert(needed == 31);
}

test "ore needed 2" {
    const data =
        \\9 ORE => 2 A
        \\8 ORE => 3 B
        \\7 ORE => 5 C
        \\3 A, 4 B => 1 AB
        \\5 B, 7 C => 1 BC
        \\4 C, 1 A => 1 CA
        \\2 AB, 3 BC, 4 CA => 1 FUEL
    ;

    var factory = Factory.init();
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        factory.parse(line);
    }
    const needed = factory.ore_needed_for_fuel(1);
    // std.debug.warn("NEEDED {} ore\n",.{ needed});
    assert(needed == 165);
}

test "ore needed 3" {
    const data =
        \\157 ORE => 5 NZVS
        \\165 ORE => 6 DCFZ
        \\44 XJWVT, 5 KHKGT, 1 QDVJ, 29 NZVS, 9 GPVTF, 48 HKGWZ => 1 FUEL
        \\12 HKGWZ, 1 GPVTF, 8 PSHF => 9 QDVJ
        \\179 ORE => 7 PSHF
        \\177 ORE => 5 HKGWZ
        \\7 DCFZ, 7 PSHF => 2 XJWVT
        \\165 ORE => 2 GPVTF
        \\3 DCFZ, 7 NZVS, 5 HKGWZ, 10 PSHF => 8 KHKGT
    ;

    var factory = Factory.init();
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        factory.parse(line);
    }
    const needed = factory.ore_needed_for_fuel(1);
    // std.debug.warn("NEEDED {} ore\n",.{ needed});
    assert(needed == 13312);
}

test "ore needed 4" {
    const data =
        \\2 VPVL, 7 FWMGM, 2 CXFTF, 11 MNCFX => 1 STKFG
        \\17 NVRVD, 3 JNWZP => 8 VPVL
        \\53 STKFG, 6 MNCFX, 46 VJHF, 81 HVMC, 68 CXFTF, 25 GNMV => 1 FUEL
        \\22 VJHF, 37 MNCFX => 5 FWMGM
        \\139 ORE => 4 NVRVD
        \\144 ORE => 7 JNWZP
        \\5 MNCFX, 7 RFSQX, 2 FWMGM, 2 VPVL, 19 CXFTF => 3 HVMC
        \\5 VJHF, 7 MNCFX, 9 VPVL, 37 CXFTF => 6 GNMV
        \\145 ORE => 6 MNCFX
        \\1 NVRVD => 8 CXFTF
        \\1 VJHF, 6 MNCFX => 4 RFSQX
        \\176 ORE => 6 VJHF
    ;

    var factory = Factory.init();
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        factory.parse(line);
    }
    const needed = factory.ore_needed_for_fuel(1);
    // std.debug.warn("NEEDED {} ore\n",.{ needed});
    assert(needed == 180697);
}

test "ore needed 5" {
    const data =
        \\171 ORE => 8 CNZTR
        \\7 ZLQW, 3 BMBT, 9 XCVML, 26 XMNCP, 1 WPTQ, 2 MZWV, 1 RJRHP => 4 PLWSL
        \\114 ORE => 4 BHXH
        \\14 VRPVC => 6 BMBT
        \\6 BHXH, 18 KTJDG, 12 WPTQ, 7 PLWSL, 31 FHTLT, 37 ZDVW => 1 FUEL
        \\6 WPTQ, 2 BMBT, 8 ZLQW, 18 KTJDG, 1 XMNCP, 6 MZWV, 1 RJRHP => 6 FHTLT
        \\15 XDBXC, 2 LTCX, 1 VRPVC => 6 ZLQW
        \\13 WPTQ, 10 LTCX, 3 RJRHP, 14 XMNCP, 2 MZWV, 1 ZLQW => 1 ZDVW
        \\5 BMBT => 4 WPTQ
        \\189 ORE => 9 KTJDG
        \\1 MZWV, 17 XDBXC, 3 XCVML => 2 XMNCP
        \\12 VRPVC, 27 CNZTR => 2 XDBXC
        \\15 KTJDG, 12 BHXH => 5 XCVML
        \\3 BHXH, 2 VRPVC => 7 MZWV
        \\121 ORE => 7 VRPVC
        \\7 XCVML => 6 RJRHP
        \\5 BHXH, 4 VRPVC => 5 LTCX
    ;

    var factory = Factory.init();
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        factory.parse(line);
    }
    const needed = factory.ore_needed_for_fuel(1);
    // std.debug.warn("NEEDED {} ore\n",.{ needed});
    assert(needed == 2210736);
}

test "fuel possible to make 3" {
    const data =
        \\157 ORE => 5 NZVS
        \\165 ORE => 6 DCFZ
        \\44 XJWVT, 5 KHKGT, 1 QDVJ, 29 NZVS, 9 GPVTF, 48 HKGWZ => 1 FUEL
        \\12 HKGWZ, 1 GPVTF, 8 PSHF => 9 QDVJ
        \\179 ORE => 7 PSHF
        \\177 ORE => 5 HKGWZ
        \\7 DCFZ, 7 PSHF => 2 XJWVT
        \\165 ORE => 2 GPVTF
        \\3 DCFZ, 7 NZVS, 5 HKGWZ, 10 PSHF => 8 KHKGT
    ;

    var factory = Factory.init();
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        factory.parse(line);
    }
    const result = factory.fuel_possible(1000000000000);
    assert(result == 82892753);
}

test "fuel possible to make 4" {
    const data =
        \\2 VPVL, 7 FWMGM, 2 CXFTF, 11 MNCFX => 1 STKFG
        \\17 NVRVD, 3 JNWZP => 8 VPVL
        \\53 STKFG, 6 MNCFX, 46 VJHF, 81 HVMC, 68 CXFTF, 25 GNMV => 1 FUEL
        \\22 VJHF, 37 MNCFX => 5 FWMGM
        \\139 ORE => 4 NVRVD
        \\144 ORE => 7 JNWZP
        \\5 MNCFX, 7 RFSQX, 2 FWMGM, 2 VPVL, 19 CXFTF => 3 HVMC
        \\5 VJHF, 7 MNCFX, 9 VPVL, 37 CXFTF => 6 GNMV
        \\145 ORE => 6 MNCFX
        \\1 NVRVD => 8 CXFTF
        \\1 VJHF, 6 MNCFX => 4 RFSQX
        \\176 ORE => 6 VJHF
    ;

    var factory = Factory.init();
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        factory.parse(line);
    }
    const result = factory.fuel_possible(1000000000000);
    assert(result == 5586022);
}

test "fuel possible to make 5" {
    const data =
        \\171 ORE => 8 CNZTR
        \\7 ZLQW, 3 BMBT, 9 XCVML, 26 XMNCP, 1 WPTQ, 2 MZWV, 1 RJRHP => 4 PLWSL
        \\114 ORE => 4 BHXH
        \\14 VRPVC => 6 BMBT
        \\6 BHXH, 18 KTJDG, 12 WPTQ, 7 PLWSL, 31 FHTLT, 37 ZDVW => 1 FUEL
        \\6 WPTQ, 2 BMBT, 8 ZLQW, 18 KTJDG, 1 XMNCP, 6 MZWV, 1 RJRHP => 6 FHTLT
        \\15 XDBXC, 2 LTCX, 1 VRPVC => 6 ZLQW
        \\13 WPTQ, 10 LTCX, 3 RJRHP, 14 XMNCP, 2 MZWV, 1 ZLQW => 1 ZDVW
        \\5 BMBT => 4 WPTQ
        \\189 ORE => 9 KTJDG
        \\1 MZWV, 17 XDBXC, 3 XCVML => 2 XMNCP
        \\12 VRPVC, 27 CNZTR => 2 XDBXC
        \\15 KTJDG, 12 BHXH => 5 XCVML
        \\3 BHXH, 2 VRPVC => 7 MZWV
        \\121 ORE => 7 VRPVC
        \\7 XCVML => 6 RJRHP
        \\5 BHXH, 4 VRPVC => 5 LTCX
    ;

    var factory = Factory.init();
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        factory.parse(line);
    }
    const result = factory.fuel_possible(1000000000000);
    assert(result == 460664);
}
