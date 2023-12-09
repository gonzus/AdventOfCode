const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Sensor = struct {
    const Readings = std.ArrayList(isize);

    allocator: Allocator,
    readings: Readings,
    reversed: Readings,
    sum_beg: isize,
    sum_end: isize,

    pub fn init(allocator: Allocator) Sensor {
        var self = Sensor{
            .allocator = allocator,
            .readings = Readings.init(allocator),
            .reversed = Readings.init(allocator),
            .sum_beg = 0,
            .sum_end = 0,
        };
        return self;
    }

    pub fn deinit(self: *Sensor) void {
        self.reversed.deinit();
        self.readings.deinit();
    }

    pub fn addLine(self: *Sensor, line: []const u8) !void {
        self.readings.clearRetainingCapacity();
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        while (it.next()) |chunk| {
            const n = try std.fmt.parseInt(isize, chunk, 10);
            try self.readings.append(n);
        }

        self.reversed.clearRetainingCapacity();
        for (self.readings.items, 0..) |_, p| {
            const n = self.readings.items[self.readings.items.len - p - 1];
            try self.reversed.append(n);
        }

        self.sum_end += try findDiff(&self.readings);
        self.sum_beg += try findDiff(&self.reversed);
    }

    fn findDiff(readings: *Readings) !isize {
        var items = readings.items;
        var top = items.len;
        var done = false;
        while (top >= 2) : (top -= 1) {
            done = true;
            for (0..top - 1) |p| {
                items[p] = items[p + 1] - items[p];
                if (items[p] != 0) done = false;
            }
            if (done) break;
        }
        if (!done) unreachable;
        var sum = items[top - 1];
        while (top < items.len) : (top += 1) {
            sum += items[top];
        }
        return sum;
    }

    pub fn getBegSum(self: *Sensor) !isize {
        return self.sum_beg;
    }

    pub fn getEndSum(self: *Sensor) !isize {
        return self.sum_end;
    }
};

test "sample part 1" {
    const data =
        \\0 3 6 9 12 15
        \\1 3 6 10 15 21
        \\10 13 16 21 30 45
    ;

    var sensor = Sensor.init(std.testing.allocator);
    defer sensor.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try sensor.addLine(line);
    }

    const sum = try sensor.getEndSum();
    const expected = @as(isize, 114);
    try testing.expectEqual(expected, sum);
}

test "sample part 2" {
    const data =
        \\0 3 6 9 12 15
        \\1 3 6 10 15 21
        \\10 13 16 21 30 45
    ;

    var sensor = Sensor.init(std.testing.allocator);
    defer sensor.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try sensor.addLine(line);
    }

    const sum = try sensor.getBegSum();
    const expected = @as(isize, 2);
    try testing.expectEqual(expected, sum);
}
