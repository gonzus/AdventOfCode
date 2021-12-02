const std = @import("std");
const testing = std.testing;
const StringTable = @import("./strtab.zig").StringTable;

const allocator = std.heap.page_allocator;

pub const Food = struct {
    const Mask = struct {
        bits: [256]u1,

        pub fn init() Mask {
            var self = Mask{
                .bits = [_]u1{0} ** 256,
            };
            return self;
        }

        pub fn show(self: Mask) void {
            var print = false;
            for (self.bits) |_, j| {
                const p = 256 - j - 1;
                const b = self.bits[p];
                print = print or b == 1;
                if (!print) continue;
                std.debug.warn("{}", .{b});
            }
        }

        pub fn check(self: Mask, bit: usize) bool {
            return self.bits[bit] == 1;
        }

        pub fn set(self: *Mask, bit: usize) void {
            self.bits[bit] = 1;
        }

        pub fn clr(self: *Mask, bit: usize) void {
            self.bits[bit] = 0;
        }

        pub fn and_with(self: *Mask, other: Mask) void {
            for (other.bits) |b, p| {
                if (self.bits[p] == 0 or b == 0) {
                    self.bits[p] = 0;
                }
            }
        }
    };

    const Allergen = struct {
        code: usize,
        mask: Mask,

        pub fn init(code: usize, mask: Mask) Allergen {
            var self = Allergen{
                .code = code,
                .mask = mask,
            };
            return self;
        }
    };

    allergens: std.AutoHashMap(usize, Allergen),
    lines: std.ArrayList(Mask),
    foods_st: StringTable,
    allergens_st: StringTable,

    pub fn init() Food {
        var self = Food{
            .allergens = std.AutoHashMap(usize, Allergen).init(allocator),
            .lines = std.ArrayList(Mask).init(allocator),
            .foods_st = StringTable.init(allocator),
            .allergens_st = StringTable.init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Food) void {
        self.allergens_st.deinit();
        self.foods_st.deinit();
        self.lines.deinit();
        self.allergens.deinit();
    }

    pub fn add_line(self: *Food, line: []const u8) void {
        var zone: usize = 0;
        var mask = Mask.init();
        var it = std.mem.tokenize(u8, line, " ,()");
        while (it.next()) |str| {
            if (std.mem.eql(u8, str, "contains")) {
                self.lines.append(mask) catch unreachable;
                zone += 1;
                continue;
            }
            if (zone == 0) {
                const code = self.foods_st.add(str);
                // std.debug.warn("FOOD {} {}\n", .{ code, str });
                mask.set(code);
                continue;
            }
            if (zone == 1) {
                const code = self.allergens_st.add(str);

                var allergen: *Allergen = undefined;
                if (!self.allergens.contains(code)) {
                    // std.debug.warn("ALLERGEN NEW {} {}:", .{ code, str });
                    var value = Allergen.init(code, mask);
                    _ = self.allergens.put(code, value) catch unreachable;
                    allergen = &value;
                } else {
                    // std.debug.warn("ALLERGEN OLD {} {}:", .{ code, str });
                    var entry = self.allergens.getEntry(code).?;
                    allergen = &entry.value_ptr.*;
                    allergen.*.mask.and_with(mask);
                }
                // allergen.*.mask.show();
                // std.debug.warn("\n", .{});
                continue;
            }
            @panic("ZONE");
        }
    }

    pub fn count_without_allergens(self: Food) usize {
        var foods = [_]u8{1} ** 256;
        var it1 = self.allergens.iterator();
        while (it1.next()) |kv| {
            const allergen = kv.value_ptr.*;
            // const allergen_name = self.allergens_st.get_str(allergen.code);
            // std.debug.print("ALLERGEN {} {} removes", .{ allergen.code, allergen_name });
            for (allergen.mask.bits) |b, p| {
                if (b == 0) continue;
                foods[p] = 0;
                // const food_name = self.foods_st.get_str(p);
                // std.debug.print(" {}", .{food_name});
            }
            // std.debug.print("\n", .{});
        }
        var total: usize = 0;
        for (foods) |b, p| {
            if (p >= self.foods_st.size()) continue;
            // const food_name = self.foods_st.get_str(p);
            if (b == 0) {
                // std.debug.print("FOOD {} {} is inert\n", .{ p, food_name });
                continue;
            }
            var count: usize = 0;
            var pl: usize = 0;
            while (pl < self.lines.items.len) : (pl += 1) {
                const orig = self.lines.items[pl];
                if (!orig.check(p)) continue;
                count += 1;
            }
            // std.debug.print("FOOD {} {} appears in {} lines\n", .{ p, food_name, count });
            total += count;
        }
        return total;
    }

    const Data = struct {
        food_code: usize,
        allergen_code: usize,
    };

    pub fn map_foods_to_allergens(self: *Food, buf: *[1024]u8) []const u8 {
        var data: [256]Data = undefined;
        var mapped_count: usize = 0;
        var mapped = [_]bool{false} ** 256;
        while (true) {
            var changes: usize = 0;
            var it = self.allergens.iterator();
            while (it.next()) |kv| {
                const allergen = kv.value_ptr.*;
                if (mapped[allergen.code]) continue;
                var count_food: usize = 0;
                var food_code: usize = 0;
                for (allergen.mask.bits) |b, p| {
                    if (b == 0) continue;
                    count_food += 1;
                    food_code = p;
                }
                if (count_food != 1) continue;

                // const allergen_name = self.allergens_st.get_str(allergen.code);
                // const food_name = self.foods_st.get_str(food_code);
                // std.debug.warn("ALLERGEN {} MAPS TO FOOD {}\n", .{ allergen_name, food_name });
                mapped[allergen.code] = true;
                data[mapped_count].food_code = food_code;
                data[mapped_count].allergen_code = allergen.code;
                mapped_count += 1;
                changes += 1;

                var it2 = self.allergens.iterator();
                while (it2.next()) |kv2| {
                    if (kv2.key_ptr.* == allergen.code) continue;
                    kv2.value_ptr.*.mask.clr(food_code);
                }
            }
            if (changes == 0) break;
        }
        // std.debug.warn("FOUND {} MAPPINGS\n", .{mapped_count});
        std.sort.sort(Data, data[0..mapped_count], self, cmp);
        var p: usize = 0;
        var bp: usize = 0;
        while (p < mapped_count) : (p += 1) {
            const food_name = self.foods_st.get_str(data[p].food_code).?;
            // std.debug.warn("MAPPING {} => [{}]\n", .{ p, food_name });
            if (p > 0) {
                std.mem.copy(u8, buf[bp..], ",");
                bp += 1;
            }
            std.mem.copy(u8, buf[bp..], food_name);
            bp += food_name.len;
        }
        return buf[0..bp];
    }

    fn cmp(self: *Food, l: Data, r: Data) bool {
        const lan = self.allergens_st.get_str(l.allergen_code).?;
        const ran = self.allergens_st.get_str(r.allergen_code).?;
        return std.mem.lessThan(u8, lan, ran);
    }
};

test "sample part a" {
    const data: []const u8 =
        \\mxmxvkd kfcds sqjhc nhms (contains dairy, fish)
        \\trh fvjkl sbzzf mxmxvkd (contains dairy)
        \\sqjhc fvjkl (contains soy)
        \\sqjhc mxmxvkd sbzzf (contains fish)
    ;

    var food = Food.init();
    defer food.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        food.add_line(line);
    }

    const count = food.count_without_allergens();
    try testing.expect(count == 5);
}

test "sample with gonzo names" {
    const data: []const u8 =
        \\A B C D (contains d, f)
        \\E F G A (contains d)
        \\C F (contains s)
        \\C A G (contains f)
    ;

    var food = Food.init();
    defer food.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        food.add_line(line);
    }

    const count = food.count_without_allergens();
    try testing.expect(count == 5);
}

test "sample part b" {
    const data: []const u8 =
        \\mxmxvkd kfcds sqjhc nhms (contains dairy, fish)
        \\trh fvjkl sbzzf mxmxvkd (contains dairy)
        \\sqjhc fvjkl (contains soy)
        \\sqjhc mxmxvkd sbzzf (contains fish)
    ;

    var food = Food.init();
    defer food.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        food.add_line(line);
    }

    var buf: [1024]u8 = undefined;
    var list = food.map_foods_to_allergens(&buf);
    try testing.expect(std.mem.eql(u8, list, "mxmxvkd,sqjhc,fvjkl"));
}
