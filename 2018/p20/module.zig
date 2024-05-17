const std = @import("std");
const testing = std.testing;
const Grids = @import("./util/grid.zig");

const Allocator = std.mem.Allocator;

pub const Base = struct {
    const Pos = Grids.Pos;
    const Dir = Grids.Direction;
    const INFINITY = std.math.maxInt(usize);
    const OFFSET = 5000;

    allocator: Allocator,
    distance: std.AutoHashMap(Pos, usize),
    directions: []u8,

    pub fn init(allocator: Allocator) !Base {
        return .{
            .allocator = allocator,
            .distance = std.AutoHashMap(Pos, usize).init(allocator),
            .directions = undefined,
        };
    }

    pub fn deinit(self: *Base) void {
        self.allocator.free(self.directions);
        self.distance.deinit();
    }

    pub fn addLine(self: *Base, line: []const u8) !void {
        self.directions = try self.allocator.dupe(u8, line);
    }

    pub fn show(self: Base) void {
        std.debug.print("Base with directions [{s}]\n", .{self.directions});
    }

    pub fn getMaxDoors(self: *Base) !usize {
        try self.follow();
        var doors: usize = 0;
        var it = self.distance.valueIterator();
        while (it.next()) |d| {
            if (doors < d.*) doors = d.*;
        }
        return doors;
    }

    pub fn getRoomsThatNeedDoors(self: *Base, doors: usize) !usize {
        try self.follow();
        var count: usize = 0;
        var it = self.distance.valueIterator();
        while (it.next()) |d| {
            if (d.* >= doors) count += 1;
        }
        return count;
    }

    pub fn follow(self: *Base) !void {
        var stack = std.ArrayList(Pos).init(self.allocator);
        defer stack.deinit();
        self.distance.clearRetainingCapacity();
        var curr = Pos.init(OFFSET, OFFSET);
        var prev = curr;
        for (self.directions) |d| {
            switch (d) {
                '^', '$' => {},
                '(' => try stack.append(curr),
                ')' => curr = stack.pop(),
                '|' => curr = stack.items[stack.items.len - 1],
                'N', 'S', 'E', 'W' => {
                    try curr.move(try Dir.parse(d));
                    const r = try self.distance.getOrPut(curr);
                    if (!r.found_existing) {
                        r.value_ptr.* = INFINITY;
                    }
                    const dist = (self.distance.get(prev) orelse 0) + 1;
                    if (r.value_ptr.* > dist)
                        r.value_ptr.* = dist;
                },
                else => return error.InvalidCharInRegExp,
            }
            prev = curr;
        }
    }
};

test "sample part 1 case A" {
    const data =
        \\^WNE$
    ;

    var base = try Base.init(testing.allocator);
    defer base.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try base.addLine(line);
    }

    const doors = try base.getMaxDoors();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, doors);
}

test "sample part 1 case B" {
    const data =
        \\^ENWWW(NEEE|SSE(EE|N))$
    ;

    var base = try Base.init(testing.allocator);
    defer base.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try base.addLine(line);
    }

    const doors = try base.getMaxDoors();
    const expected = @as(usize, 10);
    try testing.expectEqual(expected, doors);
}

test "sample part 1 case C" {
    const data =
        \\^ENNWSWW(NEWS|)SSSEEN(WNSE|)EE(SWEN|)NNN$
    ;

    var base = try Base.init(testing.allocator);
    defer base.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try base.addLine(line);
    }

    const doors = try base.getMaxDoors();
    const expected = @as(usize, 18);
    try testing.expectEqual(expected, doors);
}

test "sample part 1 case D" {
    const data =
        \\^ESSWWN(E|NNENN(EESS(WNSE|)SSS|WWWSSSSE(SW|NNNE)))$
    ;

    var base = try Base.init(testing.allocator);
    defer base.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try base.addLine(line);
    }

    const doors = try base.getMaxDoors();
    const expected = @as(usize, 23);
    try testing.expectEqual(expected, doors);
}

test "sample part 1 case E" {
    const data =
        \\^WSSEESWWWNW(S|NENNEEEENN(ESSSSW(NWSW|SSEN)|WSWWN(E|WWS(E|SS))))$
    ;

    var base = try Base.init(testing.allocator);
    defer base.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try base.addLine(line);
    }

    const doors = try base.getMaxDoors();
    const expected = @as(usize, 31);
    try testing.expectEqual(expected, doors);
}
