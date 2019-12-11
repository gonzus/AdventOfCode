const std = @import("std");
const assert = std.debug.assert;

pub const Ship = struct {
    hull: std.AutoHashMap(usize, Color),
    hx: usize,
    hy: usize,
    ix: usize,
    iy: usize,
    ax: usize,
    ay: usize,
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

    pub fn init(first_color: Color) Ship {
        var self = Ship{
            .hull = std.AutoHashMap(usize, Color).init(std.heap.direct_allocator),
            .hx = 500,
            .hy = 500,
            .ix = std.math.maxInt(usize),
            .iy = std.math.maxInt(usize),
            .ax = 0,
            .ay = 0,
            .dir = Direction.U,
            .painted = 0,
        };
        self.paint_color(first_color);
        return self;
    }

    pub fn deinit(self: *Ship) void {
        self.hull.deinit();
    }

    fn P(x: usize, y: usize) usize {
        return x * 10000 + y;
    }

    pub fn position(self: Ship) usize {
        return P(self.hx, self.hy);
    }

    pub fn get_color(self: *Ship, x: usize, y: usize) Color {
        const pos = P(x, y);
        if (self.hull.contains(pos)) {
            return self.hull.get(pos).?.value;
        }
        return Color.Black;
    }

    pub fn scan_color(self: *Ship) Color {
        return self.get_color(self.hx, self.hy);
    }

    pub fn paint_color(self: *Ship, c: Color) void {
        const pos = self.position();
        if (!self.hull.contains(pos)) {
            self.painted += 1;
        }
        _ = self.hull.put(pos, c) catch unreachable;
    }

    pub fn move(self: *Ship, rotation: Rotation) void {
        switch (rotation) {
            Rotation.L => self.dir = switch (self.dir) {
                Direction.U => Direction.L,
                Direction.D => Direction.R,
                Direction.L => Direction.D,
                Direction.R => Direction.U,
            },
            Rotation.R => self.dir = switch (self.dir) {
                Direction.U => Direction.R,
                Direction.D => Direction.L,
                Direction.L => Direction.U,
                Direction.R => Direction.D,
            },
        }
        var dx: i32 = 0;
        var dy: i32 = 0;
        switch (self.dir) {
            Direction.U => dy = 1,
            Direction.D => dy = -1,
            Direction.L => dx = -1,
            Direction.R => dx = 1,
        }
        self.hx = @intCast(usize, @intCast(i32, self.hx) + dx);
        self.hy = @intCast(usize, @intCast(i32, self.hy) + dy);
        if (self.ix > self.hx) self.ix = self.hx;
        if (self.iy > self.hy) self.iy = self.hy;
        if (self.ax < self.hx) self.ax = self.hx;
        if (self.ay < self.hy) self.ay = self.hy;
    }
};

test "simple" {
    std.debug.warn("\n");
    var ship = Ship.init(Ship.Color.Black);
    defer ship.deinit();

    assert(ship.painted == 1);

    assert(ship.scan_color() == Ship.Color.Black);
    ship.paint_color(Ship.Color.White);
    assert(ship.scan_color() == Ship.Color.White);
    assert(ship.painted == 1);
    ship.paint_color(Ship.Color.Black);
    assert(ship.scan_color() == Ship.Color.Black);
    assert(ship.painted == 1);

    ship.move(Ship.Rotation.L);
    assert(ship.position() == 4990500);

    ship.move(Ship.Rotation.L);
    assert(ship.position() == 4990499);

    ship.move(Ship.Rotation.L);
    assert(ship.position() == 5000499);

    ship.move(Ship.Rotation.L);
    assert(ship.position() == 5000500);

    ship.move(Ship.Rotation.R);
    assert(ship.position() == 5010500);

    ship.move(Ship.Rotation.R);
    assert(ship.position() == 5010499);

    ship.move(Ship.Rotation.R);
    assert(ship.position() == 5000499);

    ship.move(Ship.Rotation.R);
    assert(ship.position() == 5000500);
}
