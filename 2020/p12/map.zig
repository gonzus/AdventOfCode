const std = @import("std");
const testing = std.testing;

pub const Map = struct {
    pub const Navigation = enum {
        Direction,
        Waypoint,
    };

    // +---------------->
    // |        y--     X
    // |        N
    // |        ^
    // |  W  <  X  >  E
    // |  x--   v     x++
    // |        S
    // |        y++
    // v Y
    pub const Dir = enum(u8) {
        E = 0,
        N = 1,
        W = 2,
        S = 3,

        pub fn turn(direction: Dir, quarters: u8) Dir {
            return @intToEnum(Dir, (@enumToInt(direction) + quarters) % 4);
        }
    };

    const Pos = struct {
        x: isize,
        y: isize,
    };

    navigation: Navigation,
    direction: Dir,
    ship: Pos,
    waypoint: Pos,

    pub fn init(navigation: Navigation) Map {
        var self = Map{
            .navigation = navigation,
            .direction = Dir.E,
            .ship = .{ .x = 0, .y = 0 },
            .waypoint = .{ .x = 10, .y = -1 },
        };
        return self;
    }

    pub fn deinit(self: *Map) void {}

    pub fn run_action(self: *Map, line: []const u8) void {
        const action = line[0];
        const amount = std.fmt.parseInt(isize, line[1..], 10) catch unreachable;
        switch (self.navigation) {
            Navigation.Waypoint => self.move_by_waypoint(action, amount),
            Navigation.Direction => self.move_by_direction(action, amount),
        }
    }

    pub fn manhattan_distance(self: Map) usize {
        const absx = @intCast(usize, (std.math.absInt(self.ship.x) catch unreachable));
        const absy = @intCast(usize, (std.math.absInt(self.ship.y) catch unreachable));
        return absx + absy;
    }

    fn move_by_direction(self: *Map, action: u8, amount: isize) void {
        switch (action) {
            'N' => self.navigate_ship(Dir.N, amount),
            'S' => self.navigate_ship(Dir.S, amount),
            'E' => self.navigate_ship(Dir.E, amount),
            'W' => self.navigate_ship(Dir.W, amount),
            'L' => self.rotate_ship(amount),
            'R' => self.rotate_ship(360 - amount),
            'F' => self.navigate_ship(self.direction, amount),
            else => @panic("action by direction"),
        }
    }

    fn move_by_waypoint(self: *Map, action: u8, amount: isize) void {
        switch (action) {
            'N' => self.move_waypoint(0, -amount),
            'S' => self.move_waypoint(0, amount),
            'E' => self.move_waypoint(amount, 0),
            'W' => self.move_waypoint(-amount, 0),
            'L' => self.rotate_waypoint(amount),
            'R' => self.rotate_waypoint(360 - amount),
            'F' => self.move_ship(self.waypoint.x * amount, self.waypoint.y * amount),
            else => @panic("action by waypoint"),
        }
    }

    fn navigate_ship(self: *Map, direction: Dir, amount: isize) void {
        switch (direction) {
            .E => self.move_ship(amount, 0),
            .N => self.move_ship(0, -amount),
            .W => self.move_ship(-amount, 0),
            .S => self.move_ship(0, amount),
        }
    }

    fn move_ship(self: *Map, dx: isize, dy: isize) void {
        self.ship.x += dx;
        self.ship.y += dy;
    }

    fn rotate_ship(self: *Map, degrees: isize) void {
        self.direction = switch (degrees) {
            90 => Dir.turn(self.direction, 1),
            180 => Dir.turn(self.direction, 2),
            270 => Dir.turn(self.direction, 3),
            else => @panic("rotate ship"),
        };
    }

    fn move_waypoint(self: *Map, dx: isize, dy: isize) void {
        self.waypoint.x += dx;
        self.waypoint.y += dy;
    }

    fn rotate_waypoint(self: *Map, degrees: isize) void {
        switch (degrees) {
            90 => self.set_waypoint(self.waypoint.y, -self.waypoint.x),
            180 => self.set_waypoint(-self.waypoint.x, -self.waypoint.y),
            270 => self.set_waypoint(-self.waypoint.y, self.waypoint.x),
            else => @panic("rotate waypoint"),
        }
    }

    fn set_waypoint(self: *Map, x: isize, y: isize) void {
        self.waypoint.x = x;
        self.waypoint.y = y;
    }
};

test "sample direction" {
    const data: []const u8 =
        \\F10
        \\N3
        \\F7
        \\R90
        \\F11
    ;

    var map = Map.init(Map.Navigation.Direction);
    defer map.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        map.run_action(line);
    }

    const distance = map.manhattan_distance();
    testing.expect(distance == 25);
}

test "sample waypoint" {
    const data: []const u8 =
        \\F10
        \\N3
        \\F7
        \\R90
        \\F11
    ;

    var map = Map.init(Map.Navigation.Waypoint);
    defer map.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        map.run_action(line);
    }

    const distance = map.manhattan_distance();
    testing.expect(distance == 286);
}
