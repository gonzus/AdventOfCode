const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

const MAX_DIFF = 5;
const MAX_TAIL = 10;

const DeltaX = [MAX_DIFF][MAX_DIFF]i32{
[_]i32{ -1, -1, -1, -1, -1 },
[_]i32{ -1,  0,  0,  0, -1 },
[_]i32{  0,  0,  0,  0,  0 },
[_]i32{  1,  0,  0,  0,  1 },
[_]i32{  1,  1,  1,  1,  1 },
};
const DeltaY = [MAX_DIFF][MAX_DIFF]i32{
[_]i32{ -1, -1,  0,  1,  1 },
[_]i32{ -1,  0,  0,  0,  1 },
[_]i32{ -1,  0,  0,  0,  1 },
[_]i32{ -1,  0,  0,  0,  1 },
[_]i32{ -1, -1,  0,  1,  1 },
};

const Pos = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Pos {
        var self = Pos{
            .x = x,
            .y = y,
        };
        return self;
    }

    pub fn displace(self: *Pos, dx: i32, dy: i32) void {
        self.x += dx;
        self.y += dy;
    }
};

pub const Map = struct {
    visits: std.AutoHashMap(Pos, void),
    pos: [MAX_TAIL]Pos,
    tails: usize,

    pub fn init(allocator: Allocator, tails: usize) !Map {
        var self = Map{
            .visits = std.AutoHashMap(Pos, void).init(allocator),
            .pos = [_]Pos{ .{.x = 0, .y = 0} } ** MAX_TAIL,
            .tails = tails,
        };
        try self.remember_tail();
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.visits.deinit();
    }

    fn remember_tail(self: *Map) !void {
        _ = try self.visits.getOrPut(self.pos[self.tails]);
    }

    fn chase(self: *Map, lpos: u8) !void {
        const fpos = lpos + 1;
        const diffX = self.pos[lpos].x - self.pos[fpos].x;
        const diffY = self.pos[lpos].y - self.pos[fpos].y;
        const posX = @intCast(usize, diffX + 2);
        const posY = @intCast(usize, diffY + 2);
        self.pos[fpos].displace(DeltaX[posX][posY], DeltaY[posX][posY]);
    }

    fn move(self: *Map, dx: i32, dy: i32, len: usize) !void {
        var l: usize = 0;
        while (l < len) : (l += 1) {
            self.pos[0].displace(dx, dy);

            var p: u8 = 0;
            while (p < self.tails) : (p += 1) {
                try self.chase(p);
            }
            try self.remember_tail();
        }
    }

    pub fn add_line(self: *Map, line: []const u8) !void {
        var it = std.mem.tokenize(u8, line, " ");
        const dir = it.next().?;
        const len = try std.fmt.parseInt(usize, it.next().?, 10);
        switch (dir[0]) {
            'U' => try self.move(0, -1, len),
            'D' => try self.move(0, 1, len),
            'L' => try self.move(-1, 0, len),
            'R' => try self.move(1, 0, len),
            else => unreachable,
        }
    }

    pub fn count_tail_visits(self: Map) usize {
        var count = self.visits.count();
        return count;
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\R 4
        \\U 4
        \\L 3
        \\D 1
        \\R 4
        \\D 1
        \\L 5
        \\R 2
    ;

    var map = try Map.init(std.testing.allocator, 1);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.add_line(line);
    }

    const count = map.count_tail_visits();
    try testing.expect(count == 13);
}

test "sample part 2 a" {
    const data: []const u8 =
        \\R 4
        \\U 4
        \\L 3
        \\D 1
        \\R 4
        \\D 1
        \\L 5
        \\R 2
    ;

    var map = try Map.init(std.testing.allocator, 9);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.add_line(line);
    }

    const count = map.count_tail_visits();
    try testing.expect(count == 1);
}

test "sample part 2 b" {
    const data: []const u8 =
        \\R 5
        \\U 8
        \\L 8
        \\D 3
        \\R 17
        \\D 10
        \\L 25
        \\U 20
    ;

    var map = try Map.init(std.testing.allocator, 9);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.add_line(line);
    }

    const count = map.count_tail_visits();
    try testing.expect(count == 36);
}
