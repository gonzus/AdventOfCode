const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Memory = struct {
    const Pos = Math.Vector(isize, 2);

    data: usize,
    values: std.AutoHashMap(Pos, usize),

    pub fn init(allocator: Allocator) Memory {
        return .{
            .data = 0,
            .values = std.AutoHashMap(Pos, usize).init(allocator),
        };
    }

    pub fn deinit(self: *Memory) void {
        self.values.deinit();
    }

    pub fn addLine(self: *Memory, line: []const u8) !void {
        self.data = try std.fmt.parseUnsigned(usize, line, 10);
    }

    pub fn getStepsToCenter(self: Memory) usize {
        var x: isize = 0;
        var y: isize = 0;
        var dx: isize = 0;
        var dy: isize = -1;
        for (1..self.data) |_| {
            if (x == y or (x < 0 and x == -y) or (x > 0 and x == 1 - y)) {
                const t = dx;
                dx = -dy;
                dy = t;
            }
            x += dx;
            y += dy;
        }
        return @abs(x) + @abs(y);
    }

    pub fn getFirstLargerValue(self: *Memory) !usize {
        var x: isize = 0;
        var y: isize = 0;
        var dx: isize = 0;
        var dy: isize = -1;
        try self.values.put(Pos.init(), 1);
        for (1..self.data) |_| {
            if (x == y or (x < 0 and x == -y) or (x > 0 and x == 1 - y)) {
                const t = dx;
                dx = -dy;
                dy = t;
            }
            x += dx;
            y += dy;
            const v = self.getSumNeighbors(x, y);
            if (v > self.data) return v;
            const p = Pos.copy(&[_]isize{ x, y });
            try self.values.put(p, v);
        }
        return 0;
    }

    fn getSumNeighbors(self: Memory, x: isize, y: isize) usize {
        var sum: usize = 0;
        var dx: isize = -1;
        while (dx <= 1) : (dx += 1) {
            var dy: isize = -1;
            while (dy <= 1) : (dy += 1) {
                if (dx == 0 and dy == 0) continue;
                const p = Pos.copy(&[_]isize{ x + dx, y + dy });
                if (self.values.get(p)) |v| {
                    sum += v;
                }
            }
        }
        return sum;
    }
};

test "sample part 1 case A" {
    const data =
        \\1
    ;

    var memory = Memory.init(testing.allocator);
    defer memory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try memory.addLine(line);
    }

    const steps = memory.getStepsToCenter();
    const expected = @as(usize, 0);
    try testing.expectEqual(expected, steps);
}

test "sample part 1 case B" {
    const data =
        \\12
    ;

    var memory = Memory.init(testing.allocator);
    defer memory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try memory.addLine(line);
    }

    const steps = memory.getStepsToCenter();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, steps);
}

test "sample part 1 case C" {
    const data =
        \\23
    ;

    var memory = Memory.init(testing.allocator);
    defer memory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try memory.addLine(line);
    }

    const steps = memory.getStepsToCenter();
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, steps);
}

test "sample part 1 case D" {
    const data =
        \\1024
    ;

    var memory = Memory.init(testing.allocator);
    defer memory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try memory.addLine(line);
    }

    const steps = memory.getStepsToCenter();
    const expected = @as(usize, 31);
    try testing.expectEqual(expected, steps);
}

test "sample part 2" {
    const data =
        \\800
    ;

    var memory = Memory.init(testing.allocator);
    defer memory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try memory.addLine(line);
    }

    const value = try memory.getFirstLargerValue();
    const expected = @as(usize, 806);
    try testing.expectEqual(expected, value);
}
