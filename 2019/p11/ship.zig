const std = @import("std");
const assert = std.debug.assert;

pub const Pos = struct {
    x: usize,
    y: usize,

    pub fn encode(self: Pos) usize {
        return self.x * 10000 + self.y;
    }
};

pub const Hull = struct {
    cells: std.AutoHashMap(usize, Color),
    curr: Pos,
    pmin: Pos,
    pmax: Pos,
    dir: Direction,
    painted: usize,

    pub const Color = enum(u8) {
        Black = 0,
        White = 1,
    };

    pub const Direction = enum(u8) {
        U = 0,
        D = 1,
        L = 2,
        R = 3,
    };

    pub const Rotation = enum(u8) {
        L = 0,
        R = 1,
    };

    pub fn init(first_color: Color) Hull {
        var self = Hull{
            .cells = std.AutoHashMap(usize, Color).init(std.heap.direct_allocator),
            .curr = Pos{ .x = 500, .y = 500 },
            .pmin = Pos{ .x = std.math.maxInt(usize), .y = std.math.maxInt(usize) },
            .pmax = Pos{ .x = 0, .y = 0 },
            .dir = Direction.U,
            .painted = 0,
        };
        self.paint(first_color);
        return self;
    }

    pub fn deinit(self: *Hull) void {
        self.cells.deinit();
    }

    pub fn position(self: Hull) usize {
        return self.curr.encode();
    }

    pub fn get_color(self: *Hull, pos: Pos) Color {
        const label = pos.encode();
        if (self.cells.contains(label)) {
            return self.cells.get(label).?.value;
        }
        return Color.Black;
    }

    pub fn get_current_color(self: *Hull) Color {
        return self.get_color(self.curr);
    }

    pub fn paint(self: *Hull, c: Color) void {
        const pos = self.position();
        if (!self.cells.contains(pos)) {
            self.painted += 1;
        }
        _ = self.cells.put(pos, c) catch unreachable;
    }

    pub fn move(self: *Hull, rotation: Rotation) void {
        self.dir = switch (rotation) {
            Rotation.L => switch (self.dir) {
                Direction.U => Direction.L,
                Direction.L => Direction.D,
                Direction.D => Direction.R,
                Direction.R => Direction.U,
            },
            Rotation.R => switch (self.dir) {
                Direction.U => Direction.R,
                Direction.L => Direction.U,
                Direction.D => Direction.L,
                Direction.R => Direction.D,
            },
        };

        var dx: i32 = 0;
        var dy: i32 = 0;
        switch (self.dir) {
            Direction.U => dy = 1,
            Direction.D => dy = -1,
            Direction.L => dx = -1,
            Direction.R => dx = 1,
        }
        self.curr.x = @intCast(usize, @intCast(i32, self.curr.x) + dx);
        self.curr.y = @intCast(usize, @intCast(i32, self.curr.y) + dy);

        if (self.pmin.x > self.curr.x) self.pmin.x = self.curr.x;
        if (self.pmin.y > self.curr.y) self.pmin.y = self.curr.y;
        if (self.pmax.x < self.curr.x) self.pmax.x = self.curr.x;
        if (self.pmax.y < self.curr.y) self.pmax.y = self.curr.y;
    }
};

test "simple" {
    std.debug.warn("\n");
    var hull = Hull.init(Hull.Color.Black);
    defer hull.deinit();

    assert(hull.painted == 1);

    assert(hull.get_current_color() == Hull.Color.Black);
    hull.paint(Hull.Color.White);
    assert(hull.get_current_color() == Hull.Color.White);
    assert(hull.painted == 1);
    hull.paint(Hull.Color.Black);
    assert(hull.get_current_color() == Hull.Color.Black);
    assert(hull.painted == 1);

    hull.move(Hull.Rotation.L);
    assert(hull.position() == 4990500);

    hull.move(Hull.Rotation.L);
    assert(hull.position() == 4990499);

    hull.move(Hull.Rotation.L);
    assert(hull.position() == 5000499);

    hull.move(Hull.Rotation.L);
    assert(hull.position() == 5000500);

    hull.move(Hull.Rotation.R);
    assert(hull.position() == 5010500);

    hull.move(Hull.Rotation.R);
    assert(hull.position() == 5010499);

    hull.move(Hull.Rotation.R);
    assert(hull.position() == 5000499);

    hull.move(Hull.Rotation.R);
    assert(hull.position() == 5000500);
}
