const std = @import("std");
const testing = std.testing;

const allocator = std.heap.page_allocator;

pub const Radar = struct {
    count: usize,
    increases: usize,
    window_size: usize,
    window_data: std.ArrayList(usize),
    window_pos: usize,
    window_sum: usize,

    pub fn init(window_size: usize) Radar {
        var self = Radar{
            .count = 0,
            .increases = 0,
            .window_size = window_size,
            .window_data = std.ArrayList(usize).init(allocator),
            .window_pos = 0,
            .window_sum = 0,
        };
        return self;
    }

    pub fn deinit(self: *Radar) void {
        self.window_data.deinit();
    }

    pub fn add_line(self: *Radar, line: []const u8) void {
        self.count += 1;
        const depth = std.fmt.parseInt(usize, line, 10) catch unreachable;
        var last_sum = self.window_sum;
        if (self.count <= self.window_size) {
            self.window_data.append(depth) catch unreachable;
        } else {
            self.window_sum -= self.window_data.items[self.window_pos];
            self.window_data.items[self.window_pos] = depth;
        }
        self.window_sum += depth;
        self.window_pos = (self.window_pos + 1) % self.window_size;
        if (self.count <= self.window_size) {
            return;
        }
        if (last_sum < self.window_sum) {
            self.increases += 1;
        }
    }

    pub fn get_increases(self: *Radar) usize {
        return self.increases;
    }
};

test "sample part a" {
    const data: []const u8 =
        \\199
        \\200
        \\208
        \\210
        \\200
        \\207
        \\240
        \\269
        \\260
        \\263
    ;

    var radar = Radar.init(1);
    defer radar.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        radar.add_line(line);
    }

    const count = radar.get_increases();
    try testing.expect(count == 7);
}

test "sample part b" {
    const data: []const u8 =
        \\199
        \\200
        \\208
        \\210
        \\200
        \\207
        \\240
        \\269
        \\260
        \\263
    ;

    var radar = Radar.init(3);
    defer radar.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        radar.add_line(line);
    }

    const count = radar.get_increases();
    try testing.expect(count == 5);
}
