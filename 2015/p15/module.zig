const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Recipe = struct {
    const StringId = StringTable.StringId;

    const Property = enum {
        capacity,
        durability,
        flavor,
        texture,
        calories,

        pub fn parse(text: []const u8) !Property {
            if (std.mem.eql(u8, text, "capacity")) return .capacity;
            if (std.mem.eql(u8, text, "durability")) return .durability;
            if (std.mem.eql(u8, text, "flavor")) return .flavor;
            if (std.mem.eql(u8, text, "texture")) return .texture;
            if (std.mem.eql(u8, text, "calories")) return .calories;
            return error.InvalidProperty;
        }
    };
    const PropertySize = std.meta.tags(Property).len;

    const Ingredient = struct {
        name: StringId,
        properties: [PropertySize]isize,
        amount: isize,

        pub fn init() Ingredient {
            return Ingredient{
                .name = undefined,
                .properties = [_]isize{0} ** PropertySize,
                .amount = 0,
            };
        }
    };

    allocator: Allocator,
    max_calories: usize,
    strtab: StringTable,
    ingredients: std.ArrayList(Ingredient),
    best: usize,

    pub fn init(allocator: Allocator, max_calories: usize) Recipe {
        return Recipe{
            .allocator = allocator,
            .max_calories = max_calories,
            .strtab = StringTable.init(allocator),
            .ingredients = std.ArrayList(Ingredient).init(allocator),
            .best = 0,
        };
    }

    pub fn deinit(self: *Recipe) void {
        self.ingredients.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Recipe, line: []const u8) !void {
        var pos: usize = 0;
        var ingredient = Ingredient.init();
        var property: Property = undefined;
        var value: isize = undefined;
        var it = std.mem.tokenizeAny(u8, line, " :,");
        while (it.next()) |chunk| : (pos += 1) {
            switch (pos) {
                0 => ingredient.name = try self.strtab.add(chunk),
                1, 3, 5, 7, 9 => property = try Property.parse(chunk),
                2, 4, 6, 8, 10 => value = try std.fmt.parseInt(isize, chunk, 10),
                else => return error.InvalidData,
            }
            const p = @intFromEnum(property);
            ingredient.properties[p] = value;
        }
        try self.ingredients.append(ingredient);
    }

    pub fn show(self: Recipe) void {
        std.debug.print("Recipe with {} ingredients\n", .{self.ingredients.items.len});
        for (self.ingredients.items) |ingredient| {
            std.debug.print("  {d}:{s} =>", .{ ingredient.name, self.strtab.get_str(ingredient.name) orelse "***" });
            for (0..PropertySize) |p| {
                const property: Property = @enumFromInt(p);
                std.debug.print(" {s}={}", .{ @tagName(property), ingredient.properties[p] });
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn getBestCookieScore(self: *Recipe, teaspoons: usize) !usize {
        try self.walkAssignments(0, teaspoons);
        return self.best;
    }

    fn walkAssignments(self: *Recipe, pos: usize, left: usize) !void {
        const size = self.ingredients.items.len;
        if (pos == size) {
            var prod: usize = 1;
            var calories: isize = 0;
            for (0..PropertySize) |p| {
                const is_calories = p == @intFromEnum(Property.calories);
                var score: isize = 0;
                for (self.ingredients.items) |ingredient| {
                    const delta = ingredient.amount * ingredient.properties[p];
                    if (is_calories) {
                        calories += delta;
                    } else {
                        score += delta;
                    }
                }
                if (is_calories) continue;
                if (score < 0) score = 0;
                prod *= @intCast(score);
            }
            const valid = self.max_calories == 0 or calories == self.max_calories;
            if (valid and self.best < prod) self.best = prod;
            return;
        }
        if (pos == size - 1) {
            // last assignment
            self.ingredients.items[pos].amount = @intCast(left);
            try self.walkAssignments(pos + 1, 0);
            return;
        }
        for (0..left + 1) |amount| {
            self.ingredients.items[pos].amount = @intCast(amount);
            try self.walkAssignments(pos + 1, left - amount);
        }
    }
};

test "sample part 1" {
    const data =
        \\Butterscotch: capacity -1, durability -2, flavor 6, texture 3, calories 8
        \\Cinnamon: capacity 2, durability 3, flavor -2, texture -1, calories 3
    ;

    var recipe = Recipe.init(std.testing.allocator, 0);
    defer recipe.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try recipe.addLine(line);
    }
    // recipe.show();

    const score = try recipe.getBestCookieScore(100);
    const expected = @as(usize, 62842880);
    try testing.expectEqual(expected, score);
}

test "sample part 2" {
    const data =
        \\Butterscotch: capacity -1, durability -2, flavor 6, texture 3, calories 8
        \\Cinnamon: capacity 2, durability 3, flavor -2, texture -1, calories 3
    ;

    var recipe = Recipe.init(std.testing.allocator, 500);
    defer recipe.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try recipe.addLine(line);
    }
    // recipe.show();

    const score = try recipe.getBestCookieScore(100);
    const expected = @as(usize, 57600000);
    try testing.expectEqual(expected, score);
}
