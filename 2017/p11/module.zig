const std = @import("std");
const testing = std.testing;

pub const Grid = struct {
    const Dir = enum {
        n,
        nw,
        ne,
        sw,
        se,
        s,

        pub fn parse(str: []const u8) !Dir {
            for (std.meta.tags(Dir)) |d| {
                if (std.mem.eql(u8, str, @tagName(d))) return d;
            }
            return error.InvalidDir;
        }
    };

    const Hex = struct {
        x: isize,
        y: isize,
        z: isize,

        pub fn init(x: isize, y: isize, z: isize) Hex {
            return .{ .x = x, .y = y, .z = z };
        }

        pub fn moveDir(self: Hex, dir: Dir) Hex {
            var pos = self;
            switch (dir) {
                .n => {
                    pos.x += 1;
                    pos.y -= 1;
                },
                .nw => {
                    pos.x += 1;
                    pos.z -= 1;
                },
                .ne => {
                    pos.z += 1;
                    pos.y -= 1;
                },
                .sw => {
                    pos.y += 1;
                    pos.z -= 1;
                },
                .se => {
                    pos.z += 1;
                    pos.x -= 1;
                },
                .s => {
                    pos.y += 1;
                    pos.x -= 1;
                },
            }
            return pos;
        }

        pub fn distanceTo(self: Hex, other: Hex) usize {
            const dx: usize = @abs(self.x - other.x);
            const dy: usize = @abs(self.y - other.y);
            const dz: usize = @abs(self.z - other.z);
            return (dx + dy + dz) / 2;
        }
    };
    const Origin = Hex.init(0, 0, 0);

    pos: Hex,
    farthest: usize,

    pub fn init() Grid {
        return .{
            .pos = Origin,
            .farthest = 0,
        };
    }

    pub fn addLine(self: *Grid, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ',');
        while (it.next()) |chunk| {
            const dir = try Dir.parse(chunk);
            const pos = self.pos.moveDir(dir);
            const dist = self.pos.distanceTo(Origin);
            if (self.farthest < dist) self.farthest = dist;
            self.pos = pos;
        }
    }

    pub fn getDistanceFromOrigin(self: Grid) usize {
        return self.pos.distanceTo(Origin);
    }

    pub fn getFarthestDistance(self: Grid) usize {
        return self.farthest;
    }
};

test "sample part 1 case A" {
    const data =
        \\ne,ne,ne
    ;

    var grid = Grid.init();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try grid.addLine(line);
    }

    const distance = grid.getDistanceFromOrigin();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, distance);
}

test "sample part 1 case B" {
    const data =
        \\ne,ne,sw,sw
    ;

    var grid = Grid.init();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try grid.addLine(line);
    }

    const distance = grid.getDistanceFromOrigin();
    const expected = @as(usize, 0);
    try testing.expectEqual(expected, distance);
}

test "sample part 1 case C" {
    const data =
        \\ne,ne,s,s
    ;

    var grid = Grid.init();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try grid.addLine(line);
    }

    const distance = grid.getDistanceFromOrigin();
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, distance);
}

test "sample part 1 case D" {
    const data =
        \\se,sw,se,sw,sw
    ;

    var grid = Grid.init();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try grid.addLine(line);
    }

    const distance = grid.getDistanceFromOrigin();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, distance);
}
