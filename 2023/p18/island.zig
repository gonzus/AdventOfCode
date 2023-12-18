const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Lagoon = struct {
    const Pos = struct {
        x: isize,
        y: isize,

        pub fn init(x: isize, y: isize) Pos {
            return Pos{ .x = x, .y = y };
        }

        pub fn moveDir(self: Pos, dir: Dir, count: usize) Pos {
            const delta: isize = @intCast(count);
            return switch (dir) {
                .U => Pos.init(self.x, self.y - delta),
                .D => Pos.init(self.x, self.y + delta),
                .L => Pos.init(self.x - delta, self.y),
                .R => Pos.init(self.x + delta, self.y),
            };
        }
    };

    const Dir = enum(u8) {
        U = 'U',
        D = 'D',
        L = 'L',
        R = 'R',

        pub fn parse(c: u8) Dir {
            return switch (c) {
                'U', '3' => .U,
                'D', '1' => .D,
                'L', '2' => .L,
                'R', '0' => .R,
                else => unreachable,
            };
        }
    };

    hexa_coding: bool,
    pos: Pos,
    points: std.ArrayList(Pos),
    perimeter: usize,

    pub fn init(allocator: Allocator, hexa_coding: bool) Lagoon {
        const self = Lagoon{
            .hexa_coding = hexa_coding,
            .pos = Pos.init(0, 0),
            .points = std.ArrayList(Pos).init(allocator),
            .perimeter = 0,
        };
        return self;
    }

    pub fn deinit(self: *Lagoon) void {
        self.points.deinit();
    }

    pub fn addLine(self: *Lagoon, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        const chunk_dir = it.next().?;
        const chunk_count = it.next().?;
        const chunk_color = it.next().?;
        const dir = Dir.parse(if (self.hexa_coding) chunk_color[7] else chunk_dir[0]);
        var count: usize = 0;
        if (self.hexa_coding) {
            count = try std.fmt.parseUnsigned(usize, chunk_color[2..7], 16);
        } else {
            count = try std.fmt.parseUnsigned(usize, chunk_count, 10);
        }
        self.perimeter += count;

        self.pos = self.pos.moveDir(dir, count);
        try self.points.append(self.pos);
    }

    pub fn getSurface(self: *Lagoon) usize {
        if (self.pos.x != 0 or self.pos.y != 0) unreachable;
        // We need to add the inner area for the lagoon, to the area covered by its border.
        // Thus, we add half the perimeter and correct for all of the corner quarter turns,
        // which add up to 1.
        return self.getInnerArea() + self.getSemiPerimeter() + 1;
    }

    fn getInnerArea(self: *Lagoon) usize {
        // Shoelace formula: https://en.wikipedia.org/wiki/Shoelace_formula
        var s1: isize = 0;
        var s2: isize = 0;
        var l = self.pos;
        for (self.points.items) |r| {
            s1 += l.y * r.x;
            s2 += l.x * r.y;
            l = r;
        }
        const area_double: usize = @intCast(if (s1 > s2) (s1 - s2) else (s2 - s1));
        return area_double / 2;
    }

    fn getSemiPerimeter(self: *Lagoon) usize {
        return self.perimeter / 2;
    }
};

test "sample simple part 1" {
    const data =
        \\R 6 (#70c710)
        \\D 5 (#0dc571)
        \\L 2 (#5713f0)
        \\D 2 (#d2c081)
        \\R 2 (#59c680)
        \\D 2 (#411b91)
        \\L 5 (#8ceee2)
        \\U 2 (#caa173)
        \\L 1 (#1b58a2)
        \\U 2 (#caa171)
        \\R 2 (#7807d2)
        \\U 3 (#a77fa3)
        \\L 2 (#015232)
        \\U 2 (#7a21e3)
    ;

    var lagoon = Lagoon.init(std.testing.allocator, false);
    defer lagoon.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try lagoon.addLine(line);
    }

    const count = lagoon.getSurface();
    const expected = @as(usize, 62);
    try testing.expectEqual(expected, count);
}

test "sample simple part 2" {
    const data =
        \\R 6 (#70c710)
        \\D 5 (#0dc571)
        \\L 2 (#5713f0)
        \\D 2 (#d2c081)
        \\R 2 (#59c680)
        \\D 2 (#411b91)
        \\L 5 (#8ceee2)
        \\U 2 (#caa173)
        \\L 1 (#1b58a2)
        \\U 2 (#caa171)
        \\R 2 (#7807d2)
        \\U 3 (#a77fa3)
        \\L 2 (#015232)
        \\U 2 (#7a21e3)
    ;

    var lagoon = Lagoon.init(std.testing.allocator, true);
    defer lagoon.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try lagoon.addLine(line);
    }

    const count = lagoon.getSurface();
    const expected = @as(usize, 952408144115);
    try testing.expectEqual(expected, count);
}
