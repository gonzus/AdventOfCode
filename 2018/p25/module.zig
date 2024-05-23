const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;
const DoubleEndedQueue = @import("./util/queue.zig").DoubleEndedQueue;

const Allocator = std.mem.Allocator;

pub const Space = struct {
    const Pos = Math.Vector(isize, 4);
    const Queue = DoubleEndedQueue(usize);
    const Set = std.AutoHashMap(usize, void);

    allocator: Allocator,
    stars: std.ArrayList(Pos),

    pub fn init(allocator: Allocator) Space {
        return .{
            .allocator = allocator,
            .stars = std.ArrayList(Pos).init(allocator),
        };
    }

    pub fn deinit(self: *Space) void {
        self.stars.deinit();
    }

    pub fn addLine(self: *Space, line: []const u8) !void {
        var it = std.mem.tokenizeAny(u8, line, " ,");
        var star = Pos.init();
        var pos: usize = 0;
        while (it.next()) |chunk| : (pos += 1) {
            star.v[pos] = try std.fmt.parseInt(isize, chunk, 10);
        }
        try self.stars.append(star);
    }

    pub fn show(self: Space) void {
        std.debug.print("Space with {} stars\n", .{self.stars.items.len});
        for (self.stars.items) |star| {
            std.debug.print("  {}\n", .{star});
        }
    }

    pub fn countConstellations(self: Space) !usize {
        var neighbors = std.ArrayList(Set).init(self.allocator);
        defer {
            for (neighbors.items) |*n| {
                n.deinit();
            }
            neighbors.deinit();
        }

        // for each star compute its neighbors (stars close to it)
        for (0..self.stars.items.len) |p0| {
            try neighbors.append(Set.init(self.allocator));
            const star = self.stars.items[p0];
            for (0..self.stars.items.len) |p1| {
                const other = self.stars.items[p1];
                if (star.manhattanDist(other) > 3) continue;
                _ = try neighbors.items[p0].getOrPut(p1);
            }
        }

        // now group in disjoint constellations
        var seen = Set.init(self.allocator);
        defer seen.deinit();
        var queue = Queue.init(self.allocator);
        defer queue.deinit();
        var count: usize = 0;
        for (0..self.stars.items.len) |p| {
            if (seen.contains(p)) continue; // already processed this star
            count += 1; // got us a new star => new constellation
            queue.clearRetainingCapacity(); // iterate over transitive closure for star
            try queue.appendTail(p); // starting with the star itself
            while (!queue.empty()) {
                const s = try queue.popTail(); // for each star in the queue
                if (seen.contains(s)) continue; // already processed
                _ = try seen.getOrPut(s);
                var it = neighbors.items[s].keyIterator();
                while (it.next()) |k| {
                    try queue.appendTail(k.*); // put star's neighbors in queue
                }
            }
        }
        return count;
    }
};

test "sample part 1 case A" {
    const data =
        \\ 0,0,0,0
        \\ 3,0,0,0
        \\ 0,3,0,0
        \\ 0,0,3,0
        \\ 0,0,0,3
        \\ 0,0,0,6
        \\ 9,0,0,0
        \\12,0,0,0
    ;

    var space = Space.init(std.testing.allocator);
    defer space.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try space.addLine(line);
    }
    // space.show();

    const count = try space.countConstellations();
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, count);
}

test "sample part 1 case B" {
    const data =
        \\-1,2,2,0
        \\0,0,2,-2
        \\0,0,0,-2
        \\-1,2,0,0
        \\-2,-2,-2,2
        \\3,0,2,-1
        \\-1,3,2,2
        \\-1,0,-1,0
        \\0,2,1,-2
        \\3,0,0,0
    ;

    var space = Space.init(std.testing.allocator);
    defer space.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try space.addLine(line);
    }
    // space.show();

    const count = try space.countConstellations();
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, count);
}

test "sample part 1 case C" {
    const data =
        \\1,-1,0,1
        \\2,0,-1,0
        \\3,2,-1,0
        \\0,0,3,1
        \\0,0,-1,-1
        \\2,3,-2,0
        \\-2,2,0,0
        \\2,-2,0,-1
        \\1,-1,0,-1
        \\3,2,0,2
    ;

    var space = Space.init(std.testing.allocator);
    defer space.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try space.addLine(line);
    }
    // space.show();

    const count = try space.countConstellations();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, count);
}

test "sample part 1 case D" {
    const data =
        \\1,-1,-1,-2
        \\-2,-2,0,1
        \\0,2,1,3
        \\-2,3,-2,1
        \\0,2,3,-2
        \\-1,-1,1,-2
        \\0,-2,-1,0
        \\-2,2,3,-1
        \\1,2,2,0
        \\-1,-2,0,-2
    ;

    var space = Space.init(std.testing.allocator);
    defer space.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try space.addLine(line);
    }
    // space.show();

    const count = try space.countConstellations();
    const expected = @as(usize, 8);
    try testing.expectEqual(expected, count);
}
