const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Sensor = struct {
    const Readings = std.ArrayList(isize);

    const Pair = struct {
        beg: isize,
        end: isize,

        pub fn init() Pair {
            var self: Pair = undefined;
            self.setBegEnd(0, 0);
            return self;
        }

        pub fn setBegEnd(self: *Pair, beg: isize, end: isize) void {
            self.beg = beg;
            self.end = end;
        }
    };

    allocator: Allocator,
    readings: Readings,
    sum: Pair,

    pub fn init(allocator: Allocator) Sensor {
        var self = Sensor{
            .allocator = allocator,
            .readings = Readings.init(allocator),
            .sum = Pair.init(),
        };
        return self;
    }

    pub fn deinit(self: *Sensor) void {
        self.readings.deinit();
    }

    pub fn addLine(self: *Sensor, line: []const u8) !void {
        self.readings.clearRetainingCapacity();
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        while (it.next()) |chunk| {
            const n = try std.fmt.parseInt(isize, chunk, 10);
            try self.readings.append(n);
        }

        var extra = Pair.init();
        try self.findDiff(&self.readings, &extra);
        self.sum.beg += extra.beg;
        self.sum.end += extra.end;
    }

    fn findDiff(self: *Sensor, readings: *Readings, extra: *Pair) !void {
        if (readings.items.len < 2) return;
        extra.*.setBegEnd(readings.items[0], readings.getLast());

        var deltas = Readings.init(self.allocator);
        defer deltas.deinit();
        var done = true;
        for (0..readings.items.len - 1) |p| {
            const d = readings.items[p + 1] - readings.items[p];
            if (d != 0) done = false;
            try deltas.append(d);
        }
        if (done) return;

        var next = Pair.init();
        try self.findDiff(&deltas, &next);
        extra.*.beg -= next.beg;
        extra.*.end += next.end;
    }

    pub fn getBegSum(self: *Sensor) !isize {
        return self.sum.beg;
    }

    pub fn getEndSum(self: *Sensor) !isize {
        return self.sum.end;
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
