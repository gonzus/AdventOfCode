const std = @import("std");
const testing = std.testing;
const Pos = @import("./util/grid.zig").Pos;

const Allocator = std.mem.Allocator;

pub const Map = struct {
    allocator: Allocator,
    rows: usize,
    cols: usize,
    stars: std.ArrayList(Pos),
    count_by_row: std.AutoHashMap(usize, usize),
    count_by_col: std.AutoHashMap(usize, usize),

    pub fn init(allocator: Allocator) Map {
        var self = Map{
            .allocator = allocator,
            .rows = 0,
            .cols = 0,
            .stars = std.ArrayList(Pos).init(allocator),
            .count_by_row = std.AutoHashMap(usize, usize).init(allocator),
            .count_by_col = std.AutoHashMap(usize, usize).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.count_by_col.deinit();
        self.count_by_row.deinit();
        self.stars.deinit();
    }

    pub fn addLine(self: *Map, line: []const u8) !void {
        if (self.cols < line.len) {
            self.cols = line.len;
        }
        var row_entry = try self.count_by_row.getOrPutValue(self.rows, 0);
        for (line, 0..) |c, x| {
            if (c == '.') continue;

            const pos = Pos.init(x, self.rows);
            _ = try self.stars.append(pos);

            var col_entry = try self.count_by_col.getOrPutValue(x, 0);
            col_entry.value_ptr.* += 1;
            row_entry.value_ptr.* += 1;
        }
        self.rows += 1;
    }

    pub fn show(self: Map) void {
        std.debug.print("Map: {} x {}\n", .{ self.rows, self.cols });
        for (0..self.rows) |y| {
            for (0..self.cols) |x| {
                var l: u8 = '.';
                const pos = Pos.init(x, y);
                var star_pos: usize = std.math.maxInt(usize);
                // this is very inefficient but only used to show the map
                for (self.stars.items, 0..) |s, p| {
                    if (pos.equal(s)) {
                        star_pos = p;
                        break;
                    }
                }
                if (star_pos < std.math.maxInt(usize)) {
                    // show first 36 stars with a different character each
                    l = switch (star_pos) {
                        0...9 => '0' + @as(u8, @intCast(star_pos - 0)),
                        10...35 => 'A' + @as(u8, @intCast(star_pos - 10)),
                        else => '#',
                    };
                }
                std.debug.print("{c}", .{l});
            }
            std.debug.print("\n", .{});
        }
        for (0..self.rows) |p| {
            var entry = self.count_by_row.get(p);
            var empty = true;
            if (entry) |e| {
                empty = (e == 0);
            }
            if (empty) {
                std.debug.print("EMPTY ROW {}\n", .{p});
            }
        }
        for (0..self.cols) |p| {
            var entry = self.count_by_col.get(p);
            var empty = true;
            if (entry) |e| {
                empty = (e == 0);
            }
            if (empty) {
                std.debug.print("EMPTY COL {}\n", .{p});
            }
        }
    }

    pub fn getSumShortestPaths(self: *Map, extra: usize) !usize {
        var accum_row = std.ArrayList(usize).init(self.allocator);
        defer accum_row.deinit();
        var empty_row: usize = 0;
        for (0..self.rows) |p| {
            var empty = true;
            if (self.count_by_row.get(p)) |c| {
                empty = c == 0;
            }
            if (empty) {
                empty_row += 1;
            }
            try accum_row.append(empty_row);
        }

        var accum_col = std.ArrayList(usize).init(self.allocator);
        defer accum_col.deinit();
        var empty_col: usize = 0;
        for (0..self.cols) |p| {
            var empty = true;
            if (self.count_by_col.get(p)) |c| {
                empty = c == 0;
            }
            if (empty) {
                empty_col += 1;
            }
            try accum_col.append(empty_col);
        }

        var sum: usize = 0;
        for (0..self.stars.items.len) |p1| {
            const s1 = self.stars.items[p1];
            for (p1 + 1..self.stars.items.len) |p2| {
                const s2 = self.stars.items[p2];
                sum += s1.manhattanDistance(s2);
                sum += extraDistance(s1.x, s2.x, accum_col.items, extra);
                sum += extraDistance(s1.y, s2.y, accum_row.items, extra);
            }
        }
        return sum;
    }

    fn extraDistance(c1: usize, c2: usize, accum: []usize, extra: usize) usize {
        const delta = if (c1 < c2) accum[c2] - accum[c1] else accum[c1] - accum[c2];
        return delta * (extra - 1);
    }
};

test "sample part 1" {
    const data =
        \\...#......
        \\.......#..
        \\#.........
        \\..........
        \\......#...
        \\.#........
        \\.........#
        \\..........
        \\.......#..
        \\#...#.....
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }
    // map.show();

    const count = try map.getSumShortestPaths(2);
    const expected = @as(usize, 374);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\...#......
        \\.......#..
        \\#.........
        \\..........
        \\......#...
        \\.#........
        \\.........#
        \\..........
        \\.......#..
        \\#...#.....
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }
    // map.show();

    {
        const count = try map.getSumShortestPaths(10);
        const expected = @as(usize, 1030);
        try testing.expectEqual(expected, count);
    }
    {
        const count = try map.getSumShortestPaths(100);
        const expected = @as(usize, 8410);
        try testing.expectEqual(expected, count);
    }
}
