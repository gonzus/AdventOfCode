const std = @import("std");

pub const Tank = struct {
    mass: u32,

    pub fn init() Tank {
        return Tank{
            .mass = 0,
        };
    }

    pub fn get(self: Tank) u32 {
        return self.mass;
    }

    pub fn parse(self: *Tank, str: []u8, recurse: bool) !void {
        var value: u32 = try std.fmt.parseInt(u32, str, 10);
        while (value > 6) {
            const smaller: u32 = value / 3 - 2;
            value = smaller;
            self.mass += value;
            if (!recurse) {
                break;
            }
        }
    }
};
