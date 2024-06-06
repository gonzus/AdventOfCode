const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Factory = struct {
    const StringId = StringTable.StringId;

    const Rule = struct {
        needed: std.AutoHashMap(StringId, usize),
        produced: usize,

        pub fn init(allocator: Allocator) Rule {
            return .{
                .needed = std.AutoHashMap(StringId, usize).init(allocator),
                .produced = 0,
            };
        }

        pub fn deinit(self: *Rule) void {
            self.needed.deinit();
        }
    };

    allocator: Allocator,
    strtab: StringTable,
    rules: std.AutoHashMap(StringId, Rule),
    ore_produced: usize,
    left: std.AutoHashMap(StringId, usize),

    pub fn init(allocator: Allocator) Factory {
        return .{
            .allocator = allocator,
            .strtab = StringTable.init(allocator),
            .rules = std.AutoHashMap(StringId, Rule).init(allocator),
            .ore_produced = 0,
            .left = std.AutoHashMap(StringId, usize).init(allocator),
        };
    }

    pub fn deinit(self: *Factory) void {
        var it = self.rules.valueIterator();
        while (it.next()) |rule| {
            rule.*.deinit();
        }
        self.left.deinit();
        self.rules.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Factory, line: []const u8) !void {
        var it = std.mem.tokenizeSequence(u8, line, "=>");
        const lhs = it.next().?;
        const rhs = it.next().?;
        var rule = Rule.init(self.allocator);
        {
            var itr = std.mem.tokenizeScalar(u8, lhs, ',');
            while (itr.next()) |chunk| {
                var itp = std.mem.tokenizeScalar(u8, chunk, ' ');
                const amount: usize = try std.fmt.parseUnsigned(usize, itp.next().?, 10);
                const id = try self.strtab.add(itp.next().?);
                try rule.needed.put(id, amount);
            }
        }
        {
            var itp = std.mem.tokenizeScalar(u8, rhs, ' ');
            rule.produced = try std.fmt.parseUnsigned(usize, itp.next().?, 10);
            const id = try self.strtab.add(itp.next().?);
            try self.rules.put(id, rule);
        }
    }

    pub fn show(self: Factory) void {
        std.debug.print("Factory with {} rules\n", .{self.rules.count()});
        var it = self.rules.iterator();
        while (it.next()) |r| {
            const product = self.strtab.get_str(r.key_ptr.*) orelse "*WTF*";
            const rule = r.value_ptr.*;
            std.debug.print("  {} {s} => ", .{ rule.produced, product });
            var count: usize = 0;
            var itr = rule.needed.iterator();
            while (itr.next()) |n| : (count += 1) {
                const part = self.strtab.get_str(n.key_ptr.*) orelse "*WTF*";
                const amount = n.value_ptr.*;
                if (count > 0) {
                    std.debug.print(", ", .{});
                }
                std.debug.print("{} {s}", .{ amount, part });
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn computeOreNeededFor1Fuel(self: *Factory) !usize {
        return try self.computeOreNeededForFuel(1);
    }

    pub fn computeFuelPossibleWith1TOre(self: *Factory) !usize {
        return try self.computeFuelPossibleWithOre(1000000000000);
    }

    fn computeOreNeededForFuel(self: *Factory, amount: usize) !usize {
        self.left.clearRetainingCapacity();
        self.ore_produced = 0;
        const fuel_id = self.strtab.get_pos("FUEL") orelse return error.InvalidString;
        const ore_id = self.strtab.get_pos("ORE") orelse return error.InvalidString;
        try self.getOreNeeded(fuel_id, ore_id, amount);
        return self.ore_produced;
    }

    fn getOreNeeded(self: *Factory, material_id: StringId, ore_id: StringId, needed: usize) !void {
        var amount_left: usize = 0;
        if (self.left.get(material_id)) |material_left| {
            amount_left += material_left;
        }
        var amount_needed: usize = needed;
        if (amount_left >= amount_needed) {
            amount_left -= amount_needed;
            try self.left.put(material_id, amount_left);
            return;
        }
        if (material_id == ore_id) {
            const produced = amount_needed - amount_left;
            self.ore_produced += produced;
            amount_left = 0;
            try self.left.put(material_id, amount_left);
            return;
        }
        if (self.rules.get(material_id)) |rule| {
            if (amount_left > 0) {
                amount_needed -= amount_left;
                amount_left = 0;
            }

            const can_produce = rule.produced;
            const runs = (amount_needed + can_produce - 1) / can_produce;
            const produced = can_produce * runs;
            amount_left = produced - amount_needed;

            var it = rule.needed.iterator();
            while (it.next()) |r| {
                // we need X of a product, and have rules to produce Y,
                // which require A of m1, B of m2, etc
                // we will have to run several copies of the rule
                const ingredient_id = r.key_ptr.*;
                const ingredient_needed = runs * r.value_ptr.*;
                try self.getOreNeeded(ingredient_id, ore_id, ingredient_needed);
            }
            try self.left.put(material_id, amount_left);
        } else {
            return error.InvalidMaterial;
        }
    }

    fn computeFuelPossibleWithOre(self: *Factory, available_ore: usize) !usize {
        // we will do a binary search, need to bracket with two points
        const need_for_one = try self.computeOreNeededForFuel(1);
        var fuel_lo: usize = available_ore / need_for_one; // estimation, too small
        var fuel_hi: usize = fuel_lo * 2; // starting estimation
        var need_hi: usize = 0;
        while (true) {
            need_hi = try self.computeOreNeededForFuel(fuel_hi);
            if (need_hi >= available_ore) break;
            fuel_hi *= 2;
        }

        // with valid lo & hi values, run a classic binary search
        var j: usize = 0;
        while (true) : (j += 1) {
            const fuel_half: usize = (fuel_lo + fuel_hi) / 2;
            const need_half = try self.computeOreNeededForFuel(fuel_half);
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

test "sample part 1 case A" {
    const data =
        \\10 ORE => 10 A
        \\1 ORE => 1 B
        \\7 A, 1 B => 1 C
        \\7 A, 1 C => 1 D
        \\7 A, 1 D => 1 E
        \\7 A, 1 E => 1 FUEL
    ;

    var factory = Factory.init(testing.allocator);
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try factory.addLine(line);
    }
    // factory.show();

    const needed = try factory.computeOreNeededFor1Fuel();
    const expected = @as(usize, 31);
    try testing.expectEqual(expected, needed);
}

test "sample part 1 case B" {
    const data =
        \\9 ORE => 2 A
        \\8 ORE => 3 B
        \\7 ORE => 5 C
        \\3 A, 4 B => 1 AB
        \\5 B, 7 C => 1 BC
        \\4 C, 1 A => 1 CA
        \\2 AB, 3 BC, 4 CA => 1 FUEL
    ;

    var factory = Factory.init(testing.allocator);
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try factory.addLine(line);
    }
    // factory.show();

    const needed = try factory.computeOreNeededFor1Fuel();
    const expected = @as(usize, 165);
    try testing.expectEqual(expected, needed);
}

test "sample part 1 case C" {
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

    var factory = Factory.init(testing.allocator);
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try factory.addLine(line);
    }
    // factory.show();

    const needed = try factory.computeOreNeededFor1Fuel();
    const expected = @as(usize, 13312);
    try testing.expectEqual(expected, needed);
}

test "sample part 1 case D" {
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

    var factory = Factory.init(testing.allocator);
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try factory.addLine(line);
    }
    // factory.show();

    const needed = try factory.computeOreNeededFor1Fuel();
    const expected = @as(usize, 180697);
    try testing.expectEqual(expected, needed);
}

test "sample part 1 case E" {
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

    var factory = Factory.init(testing.allocator);
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try factory.addLine(line);
    }
    // factory.show();

    const needed = try factory.computeOreNeededFor1Fuel();
    const expected = @as(usize, 2210736);
    try testing.expectEqual(expected, needed);
}

test "sample part 2 case A" {
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

    var factory = Factory.init(testing.allocator);
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try factory.addLine(line);
    }
    // factory.show();

    const possible = try factory.computeFuelPossibleWith1TOre();
    const expected = @as(usize, 82892753);
    try testing.expectEqual(expected, possible);
}

test "sample part 2 case B" {
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

    var factory = Factory.init(testing.allocator);
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try factory.addLine(line);
    }
    // factory.show();

    const possible = try factory.computeFuelPossibleWith1TOre();
    const expected = @as(usize, 5586022);
    try testing.expectEqual(expected, possible);
}

test "sample part 2 case C" {
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

    var factory = Factory.init(testing.allocator);
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try factory.addLine(line);
    }
    // factory.show();

    const possible = try factory.computeFuelPossibleWith1TOre();
    const expected = @as(usize, 460664);
    try testing.expectEqual(expected, possible);
}
