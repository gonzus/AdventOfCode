const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;
const desc_usize = std.sort.desc(usize);

pub const Food = struct {
    elves: usize,
    lines: usize,
    calories: std.ArrayList(usize),

    pub fn init(allocator: Allocator) Food {
        var self = Food{
            .elves = 0,
            .lines = 0,
            .calories = std.ArrayList(usize).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Food) void {
        self.calories.deinit();
    }

    pub fn add_line(self: *Food, line: []const u8) !void {
        if (std.mem.eql(u8, line, "")) {
            self.elves += 1;
            self.lines = 0;
            return;
        }
        if (self.lines == 0) try self.calories.append(0);
        const cals = try std.fmt.parseInt(usize, line, 10);
        self.calories.items[self.elves] += cals;
        self.lines += 1;
    }

    pub fn get_top(self: Food, count: usize) usize {
        std.sort.heap(usize, self.calories.items, {}, desc_usize);
        var top: usize = 0;
        var j: usize = 0;
        while (j < count) : (j += 1) {
            top += self.calories.items[j];
        }
        return top;
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\1000
        \\2000
        \\3000
        \\
        \\4000
        \\
        \\5000
        \\6000
        \\
        \\7000
        \\8000
        \\9000
        \\
        \\10000
    ;

    var food = Food.init(std.testing.allocator);
    defer food.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try food.add_line(line);
    }

    const top = food.get_top(1);
    try testing.expectEqual(top, 24_000);
}

test "sample part 2" {
    const data: []const u8 =
        \\1000
        \\2000
        \\3000
        \\
        \\4000
        \\
        \\5000
        \\6000
        \\
        \\7000
        \\8000
        \\9000
        \\
        \\10000
    ;

    var food = Food.init(std.testing.allocator);
    defer food.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try food.add_line(line);
    }

    const top = food.get_top(3);
    try testing.expectEqual(top, 45_000);
}
