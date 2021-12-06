const std = @import("std");
const assert = std.debug.assert;

pub const Tank = struct {
    mass: u32,

    pub fn init() Tank {
        return Tank{
            .mass = 0,
        };
    }

    pub fn deinit(self: *Tank) void {
        _ = self;
    }

    pub fn get(self: Tank) u32 {
        return self.mass;
    }

    pub fn reset(self: *Tank) void {
        self.mass = 0;
    }

    pub fn parse(self: *Tank, str: []const u8, recurse: bool) u32 {
        var value: u32 = std.fmt.parseInt(u32, str, 10) catch 0;
        while (value > 6) {
            const smaller: u32 = value / 3 - 2;
            value = smaller;
            self.mass += value;
            if (!recurse) {
                break;
            }
        }
        return self.mass;
    }
};

test "simple non-recursive" {
    var tank = Tank.init();
    assert(tank.parse("12", false) == 2);
    tank.reset();
    assert(tank.parse("14", false) == 2);
    tank.reset();
    assert(tank.parse("1969", false) == 654);
    tank.reset();
    assert(tank.parse("100756", false) == 33583);
}

test "simple recursive" {
    var tank = Tank.init();
    assert(tank.parse("14", true) == 2);
    tank.reset();
    assert(tank.parse("1969", true) == 966);
    tank.reset();
    assert(tank.parse("100756", true) == 50346);
}
