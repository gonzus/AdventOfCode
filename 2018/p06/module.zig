const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Chronal = struct {
    const Pos = Math.Vector(isize, 2);
    const INFINITY = std.math.maxInt(isize);

    allocator: Allocator,
    pmin: Pos,
    pmax: Pos,
    pieces: std.ArrayList(Pos),
    inside: std.AutoHashMap(Pos, void),
    count: std.AutoHashMap(usize, isize),

    pub fn init(allocator: Allocator) Chronal {
        return .{
            .allocator = allocator,
            .pmin = Pos.copy(&[_]isize{ INFINITY, INFINITY }),
            .pmax = Pos.copy(&[_]isize{ 0, 0 }),
            .pieces = std.ArrayList(Pos).init(allocator),
            .inside = std.AutoHashMap(Pos, void).init(allocator),
            .count = std.AutoHashMap(usize, isize).init(allocator),
        };
    }

    pub fn deinit(self: *Chronal) void {
        self.count.deinit();
        self.inside.deinit();
        self.pieces.deinit();
    }

    pub fn addLine(self: *Chronal, line: []const u8) !void {
        var it = std.mem.tokenizeAny(u8, line, " ,");
        const x = try std.fmt.parseInt(isize, it.next().?, 10);
        const y = try std.fmt.parseInt(isize, it.next().?, 10);
        try self.pieces.append(Pos.copy(&[_]isize{ x, y }));
        if (self.pmin.v[0] > x) self.pmin.v[0] = x;
        if (self.pmin.v[1] > y) self.pmin.v[1] = y;
        if (self.pmax.v[0] < x) self.pmax.v[0] = x;
        if (self.pmax.v[1] < y) self.pmax.v[1] = y;
    }

    pub fn show(self: Chronal) void {
        std.debug.print("Chronal min {} max {}, with {} pieces\n", .{ self.pmin, self.pmax, self.pieces.items.len });
        for (self.pieces.items) |piece| {
            std.debug.print("Piece at {}\n", .{piece});
        }
    }

    pub fn findLargestUnsafeArea(self: *Chronal) !usize {
        try self.processArea(0);
        var largest: usize = 0;
        var itu = self.count.valueIterator();
        while (itu.next()) |c| {
            if (c.* < 0) continue;
            const count: usize = @intCast(c.*);
            if (largest < count) largest = count;
        }
        return largest;
    }

    pub fn findNearbySafeArea(self: *Chronal, max_distance: usize) !usize {
        try self.processArea(max_distance);
        return self.inside.count();
    }

    fn processArea(self: *Chronal, max_distance: usize) !void {
        self.reset();
        const length: usize = self.pieces.items.len;
        const parts: usize = max_distance / length;
        const offset: isize = @intCast(parts);
        const min_x = self.pmin.v[0] - offset - 1;
        const max_x = self.pmax.v[0] + offset + 1;
        const min_y = self.pmin.v[1] - offset - 1;
        const max_y = self.pmax.v[1] + offset + 1;
        var neighbor = std.AutoHashMap(Pos, usize).init(self.allocator);
        defer neighbor.deinit();
        var x: isize = min_x;
        while (x <= max_x) : (x += 1) {
            var y: isize = min_y;
            while (y <= max_y) : (y += 1) {
                const current = Pos.copy(&[_]isize{ x, y });
                var closest_pos: usize = INFINITY;
                var closest_dist: usize = INFINITY;
                var closest_count: usize = 0;
                var dist_sum: usize = 0;
                for (self.pieces.items, 0..) |piece, pos| {
                    const dist = Pos.manhattanDist(current, piece);
                    dist_sum += dist;
                    if (closest_dist > dist) {
                        closest_dist = dist;
                        closest_pos = pos;
                        closest_count = 1;
                        continue;
                    }
                    if (closest_dist == dist) {
                        closest_count += 1;
                        continue;
                    }
                }
                if (closest_count > 1) {
                    closest_pos = INFINITY;
                }
                try neighbor.put(current, closest_pos);
                if (dist_sum >= max_distance) continue;
                _ = try self.inside.getOrPut(current);
            }
        }
        var itn = neighbor.iterator();
        while (itn.next()) |en| {
            const pos = en.value_ptr.*;
            if (pos == INFINITY) continue;
            const current = en.key_ptr.*;
            const ec = try self.count.getOrPutValue(pos, 0);
            if (current.v[0] == min_x or current.v[0] == max_x or
                current.v[1] == min_y or current.v[1] == max_y)
            {
                ec.value_ptr.* -|= INFINITY;
            }
            ec.value_ptr.* += 1;
        }
    }

    fn reset(self: *Chronal) void {
        self.count.clearRetainingCapacity();
        self.inside.clearRetainingCapacity();
    }
};

test "sample part 1" {
    const data =
        \\1, 1
        \\1, 6
        \\8, 3
        \\3, 4
        \\5, 5
        \\8, 9
    ;

    var chronal = Chronal.init(testing.allocator);
    defer chronal.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try chronal.addLine(line);
    }
    // chronal.show();

    const area = try chronal.findLargestUnsafeArea();
    const expected = @as(usize, 17);
    try testing.expectEqual(expected, area);
}

test "sample part 2" {
    const data =
        \\1, 1
        \\1, 6
        \\8, 3
        \\3, 4
        \\5, 5
        \\8, 9
    ;

    var chronal = Chronal.init(testing.allocator);
    defer chronal.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try chronal.addLine(line);
    }
    // chronal.show();

    const area = try chronal.findNearbySafeArea(32);
    const expected = @as(usize, 16);
    try testing.expectEqual(expected, area);
}
