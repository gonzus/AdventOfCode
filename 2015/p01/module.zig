const std = @import("std");
const testing = std.testing;

pub const Building = struct {
    current: isize,

    pub fn init() Building {
        var self = Building{ .current = 0 };
        return self;
    }

    pub fn moveSanta(self: *Building, directions: []const u8) !isize {
        self.current = 0;
        for (directions) |d| {
            switch (d) {
                '(' => self.current += 1,
                ')' => self.current -= 1,
                else => return error.InvalidDirection,
            }
        }
        return self.current;
    }

    pub fn stepsUntilSantaIsInBasement(self: *Building, directions: []const u8) !isize {
        self.current = 0;
        for (directions, 1..) |d, pos| {
            switch (d) {
                '(' => self.current += 1,
                ')' => self.current -= 1,
                else => return error.InvalidDirection,
            }
            if (self.current == -1) {
                return @intCast(pos);
            }
        }
        return error.BasementNotFound;
    }
};

test "sample part 1" {
    var building = Building.init();

    {
        const final = try building.moveSanta("(())");
        const expected = @as(isize, 0);
        try testing.expectEqual(expected, final);
    }
    {
        const final = try building.moveSanta("()()");
        const expected = @as(isize, 0);
        try testing.expectEqual(expected, final);
    }
    {
        const final = try building.moveSanta("(((");
        const expected = @as(isize, 3);
        try testing.expectEqual(expected, final);
    }
    {
        const final = try building.moveSanta("(()(()(");
        const expected = @as(isize, 3);
        try testing.expectEqual(expected, final);
    }
    {
        const final = try building.moveSanta("))(((((");
        const expected = @as(isize, 3);
        try testing.expectEqual(expected, final);
    }
    {
        const final = try building.moveSanta("())");
        const expected = @as(isize, -1);
        try testing.expectEqual(expected, final);
    }
    {
        const final = try building.moveSanta("))(");
        const expected = @as(isize, -1);
        try testing.expectEqual(expected, final);
    }
    {
        const final = try building.moveSanta(")))");
        const expected = @as(isize, -3);
        try testing.expectEqual(expected, final);
    }
    {
        const final = try building.moveSanta(")())())");
        const expected = @as(isize, -3);
        try testing.expectEqual(expected, final);
    }
}

test "sample part 2" {
    var building = Building.init();

    {
        const final = try building.stepsUntilSantaIsInBasement(")");
        const expected = @as(isize, 1);
        try testing.expectEqual(expected, final);
    }
    {
        const final = try building.stepsUntilSantaIsInBasement("()())");
        const expected = @as(isize, 5);
        try testing.expectEqual(expected, final);
    }
}
