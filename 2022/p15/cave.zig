const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Cave = struct {
    const Pos = struct {
        x: isize,
        y: isize,

        pub fn init(x: isize, y: isize) Pos {
            return Pos{.x = x, .y = y};
        }
    };

    const Cell = enum(u8) {
        Maybe  = '.',
        Sensor = 'S',
        Beacon = 'B',
    };

    const Range = struct {
        beg: isize,
        end: isize,

        pub fn init(b: isize, e: isize) Range {
            return Range{.beg = b, .end = e};
        }

        pub fn less_than(_: void, l: Range, r: Range) bool {
            return l.beg < r.beg;
        }
    };

    allocator: Allocator,
    grid: std.AutoHashMap(Pos, Cell),
    beacons: std.AutoHashMap(Pos, usize),
    sensors: std.AutoHashMap(Pos, usize),
    min: Pos,
    max: Pos,
    scanned: bool,

    pub fn init(allocator: Allocator) Cave {
        var self = Cave{
            .allocator = allocator,
            .grid = std.AutoHashMap(Pos, Cell).init(allocator),
            .beacons = std.AutoHashMap(Pos, usize).init(allocator),
            .sensors = std.AutoHashMap(Pos, usize).init(allocator),
            .min = Pos.init(std.math.maxInt(isize), std.math.maxInt(isize)),
            .max = Pos.init(std.math.minInt(isize), std.math.minInt(isize)),
            .scanned = false,
        };
        return self;
    }

    pub fn deinit(self: *Cave) void {
        self.sensors.deinit();
        self.beacons.deinit();
        self.grid.deinit();
    }

    fn get_pos(self: Cave, pos: Pos) Cell {
        var what = self.grid.get(pos) orelse .Maybe;
        return what;
    }

    fn set_pos(self: *Cave, pos: Pos, what: Cell) !void {
        try self.grid.put(pos, what);
        if (self.min.x > pos.x) self.min.x = pos.x;
        if (self.max.x < pos.x) self.max.x = pos.x;
        if (self.min.y > pos.y) self.min.y = pos.y;
        if (self.max.y < pos.y) self.max.y = pos.y;
    }

    fn parse_coord(what: []const u8) !isize {
        var it = std.mem.tokenize(u8, what, "=");
        _ = it.next();
        var coord: isize = try std.fmt.parseInt(isize, it.next().?, 10);
        return coord;
    }

    fn add_sensor(self: *Cave, sensor: Pos) !void {
        try self.set_pos(sensor, .Sensor);
        _ = try self.sensors.getOrPut(sensor);
    }

    fn add_beacon(self: *Cave, beacon: Pos) !void {
        try self.set_pos(beacon, .Beacon);
        _ = try self.beacons.getOrPut(beacon);
    }

    pub fn add_line(self: *Cave, line: []const u8) !void {
        var pos: usize = 0;
        var sensor: Pos = undefined;
        var beacon: Pos = undefined;
        var it = std.mem.tokenize(u8, line, " ,:");
        while (it.next()) |what| : (pos += 1) {
            switch (pos) {
                2 => sensor.x = try parse_coord(what),
                3 => sensor.y = try parse_coord(what),
                8 => beacon.x = try parse_coord(what),
                9 => beacon.y = try parse_coord(what),
                else => {},
            }
        }
        try self.add_sensor(sensor);
        try self.add_beacon(beacon);
    }

    pub fn show(self: Cave) void {
        std.debug.print("----------\n", .{});
        var x: isize = 0;
        var y: isize = 0;

        std.debug.print("     ", .{});
        x = self.min.x;
        while (x <= self.max.x) : (x += 1) {
            std.debug.print("{}", .{@mod(x, 10)});
        }
        std.debug.print("\n", .{});

        y = self.min.y;
        while (y <= self.max.y) : (y += 1) {
            std.debug.print("{:4} ", .{y});
            x = self.min.x;
            while (x <= self.max.x) : (x += 1) {
                const pos = Pos.init(x, y);
                const c = self.get_pos(pos);
                std.debug.print("{c}", .{@enumToInt(c)});
            }
            std.debug.print("\n", .{});
        }
    }

    fn manhattan_distance(p0: Pos, p1: Pos) !usize {
        const deltax = try std.math.absInt(p0.x - p1.x);
        const deltay = try std.math.absInt(p0.y - p1.y);
        const delta = @intCast(usize, deltax + deltay);
        return @intCast(usize, delta);
    }

    fn closest_beacon(self: *Cave, sensor: Pos) !usize {
        var closest: usize = std.math.maxInt(usize);
        var it = self.beacons.iterator();
        while (it.next()) |entry| {
            const beacon = entry.key_ptr.*;
            const dist = try manhattan_distance(sensor, beacon);
            const t = @intCast(isize, dist);
            if (self.min.x > sensor.x - t) self.min.x = sensor.x - t;
            if (self.max.x < sensor.x + t) self.max.x = sensor.x + t;
            if (self.min.y > sensor.y - t) self.min.y = sensor.y - t;
            if (self.max.y < sensor.y + t) self.max.y = sensor.y + t;

            if (closest > dist) closest = dist;
        }
        return closest;
    }

    fn maybe_scan_sensors(self: *Cave) !void {
        if (self.scanned) return; // just once
        self.scanned = true;

        var it = self.sensors.iterator();
        while (it.next()) |entry| {
            const sensor = entry.key_ptr.*;
            const dist = try self.closest_beacon(sensor);
            // std.debug.print("Closest beacon to sensor {} is at {}\n", .{sensor, dist});
            entry.value_ptr.* = dist;
        }
    }

    fn scan_row_by_ranges(self: *Cave, row: isize, ranges: *std.ArrayList(Range), allowed: ?*Range) !usize {
        ranges.clearRetainingCapacity();

        var it = self.sensors.iterator();
        while (it.next()) |entry| {
            const sensor = entry.key_ptr.*;
            const dist = @intCast(isize, entry.value_ptr.*);
            const used = try std.math.absInt(sensor.y - row);
            if (used > dist) continue;

            const left = try std.math.absInt(dist - used);
            const range = Range.init(sensor.x - left, sensor.x + left);
            try ranges.append(range);
        }

        std.sort.sort(Range, ranges.items, {}, Range.less_than);

        var r0 = ranges.items[0];
        var min = r0.beg;
        var max = r0.end;
        var j: usize = 1;
        var total: isize = 0;
        while (j < ranges.items.len) : (j += 1) {
            var rj = ranges.items[j];
            if (rj.beg <= max+1) {
                // current range remains or is extended
                if (rj.end > max) {
                    max = rj.end;
                }
                continue;
            }

            // there is a gap within the ranges
            if (allowed) |a| { // we were requested a frequency
                if (max+1 == rj.beg-1) { // there is exactly one element in the gap
                    if (max >= a.beg and rj.beg <= a.end) { // current position is in allowed range
                        const col = max+1;
                        const frequency = @intCast(usize, col * 4000000 + row);
                        return frequency;
                    }
                }
            } else { // we are computing the empty spots
                total += max - min + 1;
                min = rj.beg;
                max = rj.end;
            }
        }
        if (allowed) |_| {
            return 0;
        } else {
            total += max - min + 1;
            return @intCast(usize, total);
        }
    }

    fn count_beacons_in_row(self: Cave, row: isize) usize {
        var count: usize = 0;
        var it = self.beacons.iterator();
        while (it.next()) |entry| {
            const beacon = entry.key_ptr.*;
            if (beacon.y != row) continue;
            // std.debug.print("DISCOUNT beacon at {}\n", .{beacon});
            count += 1;
        }
        return count;
    }

    pub fn count_empty_spots_in_row(self: *Cave, row: isize) !usize {
        try self.maybe_scan_sensors();

        var ranges = std.ArrayList(Range).init(self.allocator);
        defer ranges.deinit();

        var count: usize = 0;
        count += try self.scan_row_by_ranges(row, &ranges, null);
        count -= self.count_beacons_in_row(row);
        return count;
    }

    pub fn find_distress_beacon_frequency(self: *Cave, min: isize, max: isize) !usize {
        try self.maybe_scan_sensors();

        var ranges = std.ArrayList(Range).init(self.allocator);
        defer ranges.deinit();

        var frequency: usize = 0;
        var allowed = Range.init(min, max);
        var row: isize = min;
        while (row <= max) : (row += 1) {
            frequency = try self.scan_row_by_ranges(row, &ranges, &allowed);
            if (frequency > 0) break;
        }
        return frequency;
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\Sensor at x=2, y=18: closest beacon is at x=-2, y=15
        \\Sensor at x=9, y=16: closest beacon is at x=10, y=16
        \\Sensor at x=13, y=2: closest beacon is at x=15, y=3
        \\Sensor at x=12, y=14: closest beacon is at x=10, y=16
        \\Sensor at x=10, y=20: closest beacon is at x=10, y=16
        \\Sensor at x=14, y=17: closest beacon is at x=10, y=16
        \\Sensor at x=8, y=7: closest beacon is at x=2, y=10
        \\Sensor at x=2, y=0: closest beacon is at x=2, y=10
        \\Sensor at x=0, y=11: closest beacon is at x=2, y=10
        \\Sensor at x=20, y=14: closest beacon is at x=25, y=17
        \\Sensor at x=17, y=20: closest beacon is at x=21, y=22
        \\Sensor at x=16, y=7: closest beacon is at x=15, y=3
        \\Sensor at x=14, y=3: closest beacon is at x=15, y=3
        \\Sensor at x=20, y=1: closest beacon is at x=15, y=3
    ;

    var cave = Cave.init(std.testing.allocator);
    defer cave.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cave.add_line(line);
    }
    // cave.show();

    const count = try cave.count_empty_spots_in_row(10);
    try testing.expectEqual(@as(usize, 26), count);
}

test "sample part 2" {
    const data: []const u8 =
        \\Sensor at x=2, y=18: closest beacon is at x=-2, y=15
        \\Sensor at x=9, y=16: closest beacon is at x=10, y=16
        \\Sensor at x=13, y=2: closest beacon is at x=15, y=3
        \\Sensor at x=12, y=14: closest beacon is at x=10, y=16
        \\Sensor at x=10, y=20: closest beacon is at x=10, y=16
        \\Sensor at x=14, y=17: closest beacon is at x=10, y=16
        \\Sensor at x=8, y=7: closest beacon is at x=2, y=10
        \\Sensor at x=2, y=0: closest beacon is at x=2, y=10
        \\Sensor at x=0, y=11: closest beacon is at x=2, y=10
        \\Sensor at x=20, y=14: closest beacon is at x=25, y=17
        \\Sensor at x=17, y=20: closest beacon is at x=21, y=22
        \\Sensor at x=16, y=7: closest beacon is at x=15, y=3
        \\Sensor at x=14, y=3: closest beacon is at x=15, y=3
        \\Sensor at x=20, y=1: closest beacon is at x=15, y=3
    ;

    var cave = Cave.init(std.testing.allocator);
    defer cave.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cave.add_line(line);
    }
    // cave.show();

    const frequency = try cave.find_distress_beacon_frequency(0, 20);
    try testing.expectEqual(@as(usize, 56000011), frequency);
}
