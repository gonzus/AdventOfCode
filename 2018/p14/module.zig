const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Chocolate = struct {
    const SIZE = 2;
    const seeds: [SIZE]u8 = [_]u8{ 3, 7 };

    recipes: usize,
    digits: std.ArrayList(u8),
    numbers: std.ArrayList(u8),
    pos: [SIZE]usize,
    buf: [100]u8,

    pub fn init(allocator: Allocator) !Chocolate {
        var self = Chocolate{
            .recipes = 0,
            .digits = std.ArrayList(u8).init(allocator),
            .numbers = std.ArrayList(u8).init(allocator),
            .pos = [_]usize{0} ** SIZE,
            .buf = undefined,
        };
        for (0..SIZE) |p| {
            self.pos[p] = self.numbers.items.len;
            try self.numbers.append(seeds[p]);
        }
        return self;
    }

    pub fn deinit(self: *Chocolate) void {
        self.numbers.deinit();
        self.digits.deinit();
    }

    pub fn addLine(self: *Chocolate, line: []const u8) !void {
        self.recipes = 0;
        for (line) |c| {
            const d = c - '0';
            self.recipes *= 10;
            self.recipes += d;
            try self.digits.append(d);
        }
    }

    pub fn show(self: *Chocolate) void {
        std.debug.print("Chocolate with {} recipes: {d}\n", .{ self.recipes, self.digits.items });
        std.debug.print("Numbers:", .{});
        for (self.numbers.items, 0..) |n, p| {
            var l: u8 = ' ';
            var r: u8 = ' ';
            if (p == self.pos[0]) {
                l = '(';
                r = ')';
            }
            if (p == self.pos[1]) {
                l = '[';
                r = ']';
            }
            std.debug.print(" {c}{}{c}", .{ l, n, r });
        }
        std.debug.print("\n", .{});
    }

    pub fn findScoreForLast(self: *Chocolate, count: usize) ![]const u8 {
        const total = self.recipes + count;
        for (0..total) |_| {
            try self.step();
        }
        var len: usize = 0;
        for (self.recipes..total) |p| {
            self.buf[len] = self.numbers.items[p] + '0';
            len += 1;
        }
        return self.buf[0..len];
    }

    pub fn countRecipesWithEndingNumber(self: *Chocolate) !usize {
        while (true) {
            try self.step();
            for (0..2) |offset| {
                const count = self.hasRecipesAtTheEnd(offset);
                if (count > 0) return count;
            }
        }
        return 0;
    }

    fn step(self: *Chocolate) !void {
        var sum: usize = 0;
        for (0..SIZE) |p| {
            sum += self.numbers.items[self.pos[p]];
        }
        var len: usize = 0;
        while (true) {
            self.buf[len] = @intCast(sum % 10);
            len += 1;
            sum /= 10;
            if (sum == 0) break;
        }
        for (0..len) |j| {
            const p = len - j - 1;
            try self.numbers.append(self.buf[p]);
        }
        for (0..SIZE) |p| {
            const move = 1 + self.numbers.items[self.pos[p]];
            self.pos[p] += move;
            self.pos[p] %= self.numbers.items.len;
        }
    }

    fn hasRecipesAtTheEnd(self: Chocolate, offset: usize) usize {
        const len = self.numbers.items.len - offset;
        if (len < self.digits.items.len) return 0;
        const tail = self.numbers.items[len - self.digits.items.len .. len];
        if (!std.mem.eql(u8, tail, self.digits.items)) return 0;
        return len - self.digits.items.len;
    }
};

test "sample part 1 part A" {
    const data =
        \\9
    ;

    var chocolate = try Chocolate.init(testing.allocator);
    defer chocolate.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try chocolate.addLine(line);
    }

    const score = try chocolate.findScoreForLast(10);
    const expected = "5158916779";
    try testing.expectEqualStrings(expected, score);
}

test "sample part 1 part B" {
    const data =
        \\5
    ;

    var chocolate = try Chocolate.init(testing.allocator);
    defer chocolate.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try chocolate.addLine(line);
    }

    const score = try chocolate.findScoreForLast(10);
    const expected = "0124515891";
    try testing.expectEqualStrings(expected, score);
}

test "sample part 1 part C" {
    const data =
        \\18
    ;

    var chocolate = try Chocolate.init(testing.allocator);
    defer chocolate.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try chocolate.addLine(line);
    }

    const score = try chocolate.findScoreForLast(10);
    const expected = "9251071085";
    try testing.expectEqualStrings(expected, score);
}

test "sample part 1 part D" {
    const data =
        \\2018
    ;

    var chocolate = try Chocolate.init(testing.allocator);
    defer chocolate.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try chocolate.addLine(line);
    }

    const score = try chocolate.findScoreForLast(10);
    const expected = "5941429882";
    try testing.expectEqualStrings(expected, score);
}

test "sample part 2 part A" {
    const data =
        \\51589
    ;

    var chocolate = try Chocolate.init(testing.allocator);
    defer chocolate.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try chocolate.addLine(line);
    }

    const score = try chocolate.countRecipesWithEndingNumber();
    const expected = @as(usize, 9);
    try testing.expectEqual(expected, score);
}

test "sample part 2 part B" {
    const data =
        \\01245
    ;

    var chocolate = try Chocolate.init(testing.allocator);
    defer chocolate.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try chocolate.addLine(line);
    }

    const score = try chocolate.countRecipesWithEndingNumber();
    const expected = @as(usize, 5);
    try testing.expectEqual(expected, score);
}

test "sample part 2 part C" {
    const data =
        \\92510
    ;

    var chocolate = try Chocolate.init(testing.allocator);
    defer chocolate.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try chocolate.addLine(line);
    }

    const score = try chocolate.countRecipesWithEndingNumber();
    const expected = @as(usize, 18);
    try testing.expectEqual(expected, score);
}

test "sample part 2 part D" {
    const data =
        \\59414
    ;

    var chocolate = try Chocolate.init(testing.allocator);
    defer chocolate.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try chocolate.addLine(line);
    }

    const score = try chocolate.countRecipesWithEndingNumber();
    const expected = @as(usize, 2018);
    try testing.expectEqual(expected, score);
}
