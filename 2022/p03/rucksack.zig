const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Group = struct {
    total: usize,
    items: std.AutoHashMap(u8, u8),

    pub fn init(allocator: Allocator) Group {
        var self = Group{
            .total = 0,
            .items = std.AutoHashMap(u8, u8).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Group) void {
        self.items.deinit();
    }

    pub fn add_item(self: *Group, bucket: usize, item: u8) !void {
        var mask: u8 = @as(u8, 1) << @intCast(u3, bucket);
        const entry = self.items.get(item);
        if (entry) |e| {
            mask |= e;
        }
        try self.items.put(item, mask);
    }

    pub fn clear(self: *Group) void {
        self.items.clearRetainingCapacity();
    }

    fn priority_value(element: u8) usize {
        if (element >= 'a' and element <= 'z') {
            return element - 'a' + 1;
        }
        if (element >= 'A' and element <= 'Z') {
            return element - 'A' + 26 + 1;
        }
        return 0;
    }

    pub fn compute_priority(self: *Group, wanted: u8) void {
        var sum: usize = 0;
        var it = self.items.iterator();
        while (it.next()) |entry| {
            const val = entry.value_ptr.*;
            if (val != wanted) continue;
            sum += priority_value(entry.key_ptr.*);
        }
        self.clear();
        self.total += sum;
    }
};

pub const Rucksack = struct {
    compartment: Group,
    group_count: usize,
    group: Group,

    pub fn init(allocator: Allocator) Rucksack {
        var self = Rucksack{
            .compartment = Group.init(allocator),
            .group_count = 0,
            .group = Group.init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Rucksack) void {
        self.group.deinit();
        self.compartment.deinit();
    }

    fn update_compartment_priority(self: *Rucksack) void {
        self.compartment.compute_priority(0b11);
    }

    fn update_group_priority(self: *Rucksack) void {
        if (self.group_count < 2) {
            self.group_count += 1;
            return;
        }

        self.group.compute_priority(0b111);
        self.group_count = 0;
    }

    pub fn add_line(self: *Rucksack, line: []const u8) !void {
        const len = line.len;
        const mid = len / 2;
        for (line) |c, j| {
            var side: u8 = if (j < mid) 0 else 1;
            try self.compartment.add_item(side, c);
            try self.group.add_item(self.group_count, c);
        }

        self.update_group_priority();
        self.update_compartment_priority();
    }

    pub fn get_compartment_total(self: Rucksack) usize {
        return self.compartment.total;
    }

    pub fn get_group_total(self: Rucksack) usize {
        return self.group.total;
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\vJrwpWtwJgWrhcsFMMfFFhFp
        \\jqHRNqRjqzjGDLGLrsFMfFZSrLrFZsSL
        \\PmmdzqPrVvPwwTWBwg
        \\wMqvLMZHhHMvwLHjbvcjnnSBnvTQFn
        \\ttgJtRGJQctTZtZT
        \\CrZsJsPPZsGzwwsLwLmpwMDw
    ;

    var rucksack = Rucksack.init(std.testing.allocator);
    defer rucksack.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try rucksack.add_line(line);
    }

    const sum = rucksack.get_compartment_total();
    try testing.expect(sum == 157);
}

test "sample part 2" {
    const data: []const u8 =
        \\vJrwpWtwJgWrhcsFMMfFFhFp
        \\jqHRNqRjqzjGDLGLrsFMfFZSrLrFZsSL
        \\PmmdzqPrVvPwwTWBwg
        \\wMqvLMZHhHMvwLHjbvcjnnSBnvTQFn
        \\ttgJtRGJQctTZtZT
        \\CrZsJsPPZsGzwwsLwLmpwMDw
    ;

    var rucksack = Rucksack.init(std.testing.allocator);
    defer rucksack.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try rucksack.add_line(line);
    }

    const sum = rucksack.get_group_total();
    try testing.expect(sum == 70);
}
