const std = @import("std");
const testing = std.testing;
const Pos = @import("./util/grid.zig").Pos;

const Allocator = std.mem.Allocator;

pub const Map = struct {
    const Santa = struct {
        current: Pos,

        pub fn init() Santa {
            var self = Santa{ .current = undefined };
            self.reset();
            return self;
        }

        pub fn reset(self: *Santa) void {
            self.current = Pos.init(5000, 5000);
        }

        pub fn moveDir(self: *Santa, dir: u8) !void {
            switch (dir) {
                '<' => self.current.x -= 1,
                '>' => self.current.x += 1,
                '^' => self.current.y -= 1,
                'v' => self.current.y += 1,
                else => return error.InvalidMove,
            }
        }
    };

    santas: std.ArrayList(Santa),
    visited: std.AutoHashMap(Pos, void),

    pub fn init(allocator: Allocator, santa_count: usize) !Map {
        var self = Map{
            .santas = std.ArrayList(Santa).init(allocator),
            .visited = std.AutoHashMap(Pos, void).init(allocator),
        };
        for (0..santa_count) |_| {
            try self.santas.append(Santa.init());
        }
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.visited.deinit();
        self.santas.deinit();
    }

    pub fn reset(self: *Map) !void {
        self.visited.clearRetainingCapacity();
        for (self.santas.items) |*santa| {
            santa.reset();
            try self.visited.put(santa.current, {});
        }
    }

    pub fn addLine(self: *Map, line: []const u8) !void {
        try self.reset();
        const items = self.santas.items;
        for (line, 0..) |c, pos| {
            const index = pos % items.len;
            try items[index].moveDir(c);
            try self.visited.put(items[index].current, {});
        }
    }

    pub fn getTotalHousesVisited(self: Map) usize {
        return self.visited.count();
    }
};

test "sample part 1" {
    var map = try Map.init(std.testing.allocator, 1);
    defer map.deinit();

    {
        try map.addLine(">");
        const visited = map.getTotalHousesVisited();
        const expected = @as(usize, 2);
        try testing.expectEqual(expected, visited);
    }

    {
        try map.addLine("^>v<");
        const visited = map.getTotalHousesVisited();
        const expected = @as(usize, 4);
        try testing.expectEqual(expected, visited);
    }

    {
        try map.addLine("^v^v^v^v^v");
        const visited = map.getTotalHousesVisited();
        const expected = @as(usize, 2);
        try testing.expectEqual(expected, visited);
    }
}

test "sample part 2" {
    var map = try Map.init(std.testing.allocator, 2);
    defer map.deinit();

    {
        try map.addLine("^v");
        const visited = map.getTotalHousesVisited();
        const expected = @as(usize, 3);
        try testing.expectEqual(expected, visited);
    }

    {
        try map.addLine("^>v<");
        const visited = map.getTotalHousesVisited();
        const expected = @as(usize, 3);
        try testing.expectEqual(expected, visited);
    }

    {
        try map.addLine("^v^v^v^v^v");
        const visited = map.getTotalHousesVisited();
        const expected = @as(usize, 11);
        try testing.expectEqual(expected, visited);
    }
}
