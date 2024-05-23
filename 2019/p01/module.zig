const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Tank = struct {
    modules: std.ArrayList(usize),

    pub fn init(allocator: Allocator) Tank {
        return .{
            .modules = std.ArrayList(usize).init(allocator),
        };
    }

    pub fn deinit(self: *Tank) void {
        self.modules.deinit();
    }

    pub fn addLine(self: *Tank, line: []const u8) !void {
        const value = try std.fmt.parseUnsigned(usize, line, 10);
        try self.modules.append(value);
    }

    pub fn getTotalFuelRequirements(self: Tank, recurse: bool) usize {
        var total: usize = 0;
        for (self.modules.items) |mass| {
            var value = mass;
            while (true) {
                value = value / 3 - 2;
                total += value;
                if (!recurse) break;
                if (value < 6) break;
            }
        }
        return total;
    }
};

test "sample part 1" {
    const data =
        \\12
        \\14
        \\1969
        \\100756
    ;

    var tank = Tank.init(testing.allocator);
    defer tank.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try tank.addLine(line);
    }

    const total = tank.getTotalFuelRequirements(false);
    const expected = @as(usize, 2 + 2 + 654 + 33583);
    try testing.expectEqual(expected, total);
}

test "sample part 2" {
    const data =
        \\14
        \\1969
        \\100756
    ;

    var tank = Tank.init(testing.allocator);
    defer tank.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try tank.addLine(line);
    }

    const total = tank.getTotalFuelRequirements(true);
    const expected = @as(usize, 2 + 966 + 50346);
    try testing.expectEqual(expected, total);
}
