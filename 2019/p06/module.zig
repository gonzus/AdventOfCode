const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Map = struct {
    const StringId = StringTable.StringId;

    bodies: StringTable,
    parent: std.AutoHashMap(StringId, StringId),
    hops: std.AutoHashMap(StringId, usize),

    pub fn init(allocator: Allocator) Map {
        return .{
            .bodies = StringTable.init(allocator),
            .parent = std.AutoHashMap(StringId, StringId).init(allocator),
            .hops = std.AutoHashMap(StringId, usize).init(allocator),
        };
    }

    pub fn deinit(self: *Map) void {
        self.hops.deinit();
        self.parent.deinit();
        self.bodies.deinit();
    }

    pub fn addLine(self: *Map, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ')');
        const center = try self.bodies.add(it.next().?);
        const around = try self.bodies.add(it.next().?);
        try self.parent.put(around, center);
    }

    pub fn countOrbits(self: Map) usize {
        var count: usize = 0;
        for (0..self.bodies.size()) |body| {
            if (self.parent.get(body)) |center| {
                count += self.numOrbits(center);
            }
        }
        return count;
    }

    pub fn countHops(self: *Map, me: []const u8, other: []const u8) !usize {
        self.hops.clearRetainingCapacity();
        {
            var current: StringId = self.bodies.get_pos(me) orelse return error.InvalidName;
            var count_me: usize = 0;
            while (true) {
                if (self.parent.get(current)) |parent| {
                    count_me += 1;
                    current = parent;
                    _ = try self.hops.put(current, count_me);
                } else break;
            }
        }

        {
            var current: StringId = self.bodies.get_pos(other) orelse return error.InvalidName;
            var count_other: usize = 0;
            while (true) {
                if (self.parent.get(current)) |parent| {
                    count_other += 1;
                    current = parent;
                    if (self.hops.get(current)) |count_me| {
                        return count_other + count_me - 2;
                    }
                } else break;
            }
        }

        return std.math.maxInt(usize);
    }

    fn numOrbits(self: Map, body: StringId) usize {
        var count: usize = 1;
        if (self.parent.get(body)) |center| {
            count += self.numOrbits(center);
        }
        return count;
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\COM)B
        \\B)C
        \\C)D
        \\D)E
        \\E)F
        \\B)G
        \\G)H
        \\D)I
        \\E)J
        \\J)K
        \\K)L
    ;

    var map = Map.init(testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }

    const count = map.countOrbits();
    const expected = @as(usize, 42);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data: []const u8 =
        \\COM)B
        \\B)C
        \\C)D
        \\D)E
        \\E)F
        \\B)G
        \\G)H
        \\D)I
        \\E)J
        \\J)K
        \\K)L
        \\K)YOU
        \\I)SAN
    ;

    var map = Map.init(testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }

    const count = try map.countHops("YOU", "SAN");
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, count);
}
