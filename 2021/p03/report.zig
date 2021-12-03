const std = @import("std");
const testing = std.testing;

const allocator = std.heap.page_allocator;

pub const Report = struct {
    const Line = struct {
        const MAX_SIZE = 16;

        bits: [MAX_SIZE]usize,
        alive: bool,

        pub fn init() Line {
            var self = Line{
                .bits = [_]usize{0} ** MAX_SIZE,
                .alive = true,
            };
            return self;
        }

        pub fn deinit(self: *Line) void {
            _ = self;
        }

        pub fn process(self: *Line, line: []const u8) void {
            for (line) |c, j| {
                self.bits[j] += c - '0';
            }
        }

        pub fn set(self: *Line, bit: usize, value: usize) void {
            self.bits[bit] = value;
        }

        pub fn to_decimal(self: *Line, width: usize) usize {
            var num: usize = 0;
            for (self.bits) |b, j| {
                if (j >= width) break;
                num *= 2;
                num += b;
            }
            // std.debug.warn("To decimal {d}: {}\n", .{ self.bits[0..width], num });
            return num;
        }
    };

    width: usize,
    lines: std.ArrayList(Line),

    pub fn init() Report {
        var self = Report{
            .width = 0,
            .lines = std.ArrayList(Line).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Report) void {
        for (self.lines.items) |*line| {
            line.deinit();
        }
        self.lines.deinit();
    }

    pub fn process_line(self: *Report, data: []const u8) void {
        if (data.len == 0) return;

        if (self.width == 0) {
            self.width = data.len;
        }

        if (self.width != data.len) {
            unreachable;
        }

        var line = Line.init();
        line.process(data);
        self.lines.append(line) catch unreachable;
    }

    pub fn get_power_consumption(self: *Report) usize {
        var gamma = Line.init();
        defer gamma.deinit();
        var epsilon = Line.init();
        defer epsilon.deinit();
        var j: usize = 0;
        while (j < self.width) : (j += 1) {
            if (self.has_more_ones_for_bit(j, self.lines.items.len)) {
                gamma.set(j, 1);
            } else {
                epsilon.set(j, 1);
            }
        }
        return gamma.to_decimal(self.width) * epsilon.to_decimal(self.width);
    }

    pub fn get_life_support_rating(self: *Report) usize {
        return self.get_oxygen_generator_rating() * self.get_co2_scrubber_rating();
    }

    fn reset_alive(self: Report) void {
        for (self.lines.items) |*line| {
            line.alive = true;
        }
    }

    fn mark_alive_for_bit(self: Report, bit: usize, wanted: usize) usize {
        if (bit >= self.width) unreachable;
        var count: usize = 0;
        for (self.lines.items) |*line| {
            if (line.bits[bit] != wanted) {
                line.alive = false;
            }
            if (line.alive) {
                // std.debug.warn("Keeping alive line {} bit {}: {d}\n", .{ j, bit, line.bits[0..self.width] });
                count += 1;
            }
        }
        return count;
    }

    fn count_ones_for_bit(self: Report, bit: usize) usize {
        if (bit >= self.width) unreachable;
        var count: usize = 0;
        for (self.lines.items) |*line| {
            if (!line.alive) continue;
            if (line.bits[bit] != 1) continue;
            count += 1;
        }
        return count;
    }

    fn has_more_ones_for_bit(self: *Report, bit: usize, size: usize) bool {
        const half = (size + 1) / 2;
        const count = self.count_ones_for_bit(bit);
        return count >= half;
    }

    fn get_rating(self: *Report, mark: usize) usize {
        self.reset_alive();
        var j: usize = 0;
        var pass: usize = 0;
        var left: usize = self.lines.items.len;
        while (j < self.width) : (j += 1) {
            var count: usize = 0;
            if (self.has_more_ones_for_bit(j, left)) {
                count = self.mark_alive_for_bit(j, mark);
            } else {
                count = self.mark_alive_for_bit(j, 1 - mark);
            }
            if (count == 1) break;
            pass += 1;
            left = count;
        }

        for (self.lines.items) |*line| {
            if (!line.alive) continue;
            return line.to_decimal(self.width);
        }
        return 0;
    }

    fn get_oxygen_generator_rating(self: *Report) usize {
        return self.get_rating(1);
    }

    fn get_co2_scrubber_rating(self: *Report) usize {
        return self.get_rating(0);
    }
};

test "sample part a" {
    const data: []const u8 =
        \\00100
        \\11110
        \\10110
        \\10111
        \\10101
        \\01111
        \\00111
        \\11100
        \\10000
        \\11001
        \\00010
        \\01010
    ;

    var report = Report.init();
    defer report.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        report.process_line(line);
    }

    const pc = report.get_power_consumption();
    try testing.expect(pc == 198);
}

test "sample part b" {
    const data: []const u8 =
        \\00100
        \\11110
        \\10110
        \\10111
        \\10101
        \\01111
        \\00111
        \\11100
        \\10000
        \\11001
        \\00010
        \\01010
    ;

    var report = Report.init();
    defer report.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        report.process_line(line);
    }

    const lsr = report.get_life_support_rating();
    try testing.expect(lsr == 230);
}
