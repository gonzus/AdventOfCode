const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Lava = struct {
    const Pos = struct {
        x: isize,
        y: isize,
        z: isize,

        pub fn init(x: isize, y: isize, z: isize) Pos {
            return Pos{.x = x, .y = y, .z = z};
        }

        pub fn add(self: Pos, other: Pos) Pos {
            return Pos.init(self.x+other.x,self.y+other.y,self.z+other.z);
        }
    };

    allocator: Allocator,
    points: std.AutoHashMap(Pos, void),
    min: Pos,
    max: Pos,

    pub fn init(allocator: Allocator) Lava {
        var self = Lava{
            .allocator = allocator,
            .points = std.AutoHashMap(Pos, void).init(allocator),
            .min = Pos.init(std.math.maxInt(isize), std.math.maxInt(isize), std.math.maxInt(isize)),
            .max = Pos.init(std.math.minInt(isize), std.math.minInt(isize), std.math.minInt(isize)),
        };
        return self;
    }

    pub fn deinit(self: *Lava) void {
        self.points.deinit();
    }

    fn add_point(self: *Lava, pos: Pos) !void {
        _ = try self.points.getOrPut(pos);
        if (self.min.x > pos.x) self.min.x = pos.x;
        if (self.min.y > pos.y) self.min.y = pos.y;
        if (self.min.z > pos.z) self.min.z = pos.z;
        if (self.max.x < pos.x) self.max.x = pos.x;
        if (self.max.y < pos.y) self.max.y = pos.y;
        if (self.max.z < pos.z) self.max.z = pos.z;
    }

    pub fn add_line(self: *Lava, line: []const u8) !void {
        var pos: Pos = undefined;
        var it = std.mem.tokenize(u8, line, ",");
        pos.x = try std.fmt.parseInt(isize, it.next().?, 10);
        pos.y = try std.fmt.parseInt(isize, it.next().?, 10);
        pos.z = try std.fmt.parseInt(isize, it.next().?, 10);
        try self.add_point(pos);
    }

    pub fn show(self: Lava) void {
        std.debug.print("-- POINTS --------\n", .{});
        var it = self.points.iterator();
        while (it.next()) |entry| {
            const pos = entry.key_ptr.*;
            std.debug.print("{}\n", .{pos});
        }
    }

    const deltas = [_]Pos{
        Pos.init( 1,  0,  0),
        Pos.init(-1,  0,  0),
        Pos.init( 0,  1,  0),
        Pos.init( 0, -1,  0),
        Pos.init( 0,  0,  1),
        Pos.init( 0,  0, -1),
    };

    pub fn surface_area_external(self: Lava) !usize {
        var visited = std.AutoHashMap(Pos, void).init(self.allocator);
        defer visited.deinit();
        var pending = std.ArrayList(Pos).init(self.allocator);
        defer pending.deinit();

        // do a search of empty space around structure
        const start = self.min.add(Pos.init(-1, -1, -1));
        try pending.append(start);
        while (pending.items.len > 0) {
            const pos = pending.pop();
            const rp = try visited.getOrPut(pos);
            if (rp.found_existing) continue;

            for (deltas) |delta| {
                const n = pos.add(delta);
                if (n.x < self.min.x - 1 or n.x > self.max.x + 1) continue;
                if (n.y < self.min.y - 1 or n.y > self.max.y + 1) continue;
                if (n.z < self.min.z - 1 or n.z > self.max.z + 1) continue;
                if (self.points.contains(n)) continue;
                try pending.append(n);
            }
        }

        var area: usize = 0;
        var it = self.points.iterator();
        while (it.next()) |entry| {
            const pos = entry.key_ptr.*;
            for (deltas) |delta| {
                const n = pos.add(delta);
                if (!visited.contains(n)) continue;
                area += 1;
            }
        }
        return area;
    }

    pub fn surface_area_total(self: Lava) !usize {
        var area: usize = 0;
        var it = self.points.iterator();
        while (it.next()) |entry| {
            area += 6;
            const pos = entry.key_ptr.*;
            for (deltas) |delta| {
                const n = pos.add(delta);
                if (!self.points.contains(n)) continue;
                area -= 1;
            }
        }
        return area;
    }
};

test "sample part 1 a" {
    const data: []const u8 =
        \\1,1,1
        \\2,1,1
    ;

    var lava = Lava.init(std.testing.allocator);
    defer lava.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try lava.add_line(line);
    }
    // lava.show();

    const area = try lava.surface_area_external();
    try testing.expectEqual(@as(usize, 10), area);
}

test "sample part 1 b" {
    const data: []const u8 =
        \\2,2,2
        \\1,2,2
        \\3,2,2
        \\2,1,2
        \\2,3,2
        \\2,2,1
        \\2,2,3
        \\2,2,4
        \\2,2,6
        \\1,2,5
        \\3,2,5
        \\2,1,5
        \\2,3,5
    ;

    var lava = Lava.init(std.testing.allocator);
    defer lava.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try lava.add_line(line);
    }
    // lava.show();

    const area = try lava.surface_area_total();
    try testing.expectEqual(@as(usize, 64), area);
}

test "sample part 2" {
    const data: []const u8 =
        \\2,2,2
        \\1,2,2
        \\3,2,2
        \\2,1,2
        \\2,3,2
        \\2,2,1
        \\2,2,3
        \\2,2,4
        \\2,2,6
        \\1,2,5
        \\3,2,5
        \\2,1,5
        \\2,3,5
    ;

    var lava = Lava.init(std.testing.allocator);
    defer lava.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try lava.add_line(line);
    }
    // lava.show();

    const area = try lava.surface_area_external();
    try testing.expectEqual(@as(usize, 58), area);
}
