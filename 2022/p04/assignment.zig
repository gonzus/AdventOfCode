const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Range = struct {
    beg: usize,
    end: usize,

    pub fn init(beg: usize, end: usize) Range {
        var self = Range{
            .beg = beg,
            .end = end,
        };
        return self;
    }

    fn superset(self: Range, other: Range) bool {
        return self.beg <= other.beg and self.end >= other.end;
    }

    pub fn contain(self: Range, other: Range) bool {
        return superset(self, other) or superset(other, self);
    }

    pub fn overlap(self: Range, other: Range) bool {
        const ret = self.beg <= other.end and other.beg <= self.end;
        return ret;
    }
};

pub const Group = struct {
    ranges: std.ArrayList(Range),

    pub fn init(allocator: Allocator) Group {
        var self = Group{
            .ranges = std.ArrayList(Range).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Group) void {
        self.ranges.deinit();
    }
};

pub const Assignment = struct {
    allocator: Allocator,
    groups: std.ArrayList(Group),

    pub fn init(allocator: Allocator) Assignment {
        var self = Assignment{
            .allocator = allocator,
            .groups = std.ArrayList(Group).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Assignment) void {
        for (self.groups.items) |*group| {
            group.deinit();
        }
        self.groups.deinit();
    }

    pub fn add_group(self: *Assignment) !void {
        var group = Group.init(self.allocator);
        try self.groups.append(group);
    }

    pub fn add_range(self: *Assignment, beg: usize, end: usize) !void {
        const range = Range.init(beg, end);
        try self.groups.items[self.groups.items.len - 1].ranges.append(range);
    }

    pub fn add_line(self: *Assignment, line: []const u8) !void {
        try self.add_group();

        var it_line = std.mem.tokenize(u8, line, ",");
        while (it_line.next()) |rooms| {
            var beg: usize = undefined;
            var end: usize = undefined;
            var pos: usize = 0;
            var it_room = std.mem.tokenize(u8, rooms, "-");
            while (it_room.next()) |room| : (pos += 1) {
                const num = try std.fmt.parseInt(usize, room, 10);
                switch (pos) {
                    0 => beg = num,
                    1 => end = num,
                    else => unreachable,
                }
            }
            try self.add_range(beg, end);
        }
    }

    fn count_condition(self: Assignment, comptime condition: fn(r0: Range, r1: Range) bool) usize {
        var count: usize = 0;
        for (self.groups.items) |group| {
            var include = false;
            var j: usize = 0;
            while (j < group.ranges.items.len and !include) : (j += 1) {
                const r0 = group.ranges.items[j];
                var k: usize = j+1;
                while (k < group.ranges.items.len and !include) : (k += 1) {
                    const r1 = group.ranges.items[k];
                    include = condition(r0, r1);
                }
            }
            if (!include) continue;
            count += 1;
        }
        return count;
    }

    pub fn count_contained(self: Assignment) usize {
        return self.count_condition(Range.contain);
    }

    pub fn count_overlapping(self: Assignment) usize {
        return self.count_condition(Range.overlap);
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\2-4,6-8
        \\2-3,4-5
        \\5-7,7-9
        \\2-8,3-7
        \\6-6,4-6
        \\2-6,4-8
    ;

    var assignment = Assignment.init(std.testing.allocator);
    defer assignment.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try assignment.add_line(line);
    }

    const count = assignment.count_contained();
    try testing.expectEqual(count, 2);
}

test "sample part 2" {
    const data: []const u8 =
        \\2-4,6-8
        \\2-3,4-5
        \\5-7,7-9
        \\2-8,3-7
        \\6-6,4-6
        \\2-6,4-8
    ;

    var assignment = Assignment.init(std.testing.allocator);
    defer assignment.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try assignment.add_line(line);
    }

    const count = assignment.count_overlapping();
    try testing.expectEqual(count, 4);
}
