const std = @import("std");
const testing = std.testing;

pub const Charge = struct {
    const SIZE = 300;

    serial: isize,
    sum: [SIZE + 1][SIZE + 1]isize,
    buf: [100]u8,
    best_power: isize,
    best_x: isize,
    best_y: isize,
    best_size: isize,

    pub fn init() Charge {
        return .{
            .serial = 0,
            .sum = undefined,
            .buf = undefined,
            .best_power = undefined,
            .best_x = undefined,
            .best_y = undefined,
            .best_size = undefined,
        };
    }

    pub fn addLine(self: *Charge, line: []const u8) !void {
        self.serial = try std.fmt.parseInt(isize, line, 10);
    }

    pub fn findBestForSize(self: *Charge, size: usize) ![]const u8 {
        self.computePartialSums();
        self.resetBest();
        self.computeForSize(size);
        const text = try std.fmt.bufPrint(&self.buf, "{},{}", .{
            self.best_x - self.best_size + 1,
            self.best_y - self.best_size + 1,
        });
        return text;
    }

    pub fn findBestForAnySize(self: *Charge) ![]const u8 {
        self.computePartialSums();
        self.resetBest();
        for (1..SIZE + 1) |size| {
            self.computeForSize(size);
        }
        const text = try std.fmt.bufPrint(&self.buf, "{},{},{}", .{
            self.best_x - self.best_size + 1,
            self.best_y - self.best_size + 1,
            self.best_size,
        });
        return text;
    }

    fn computePartialSums(self: *Charge) void {
        for (1..SIZE + 1) |y| {
            for (1..SIZE + 1) |x| {
                const id: isize = @intCast(x + 10);
                var p: isize = @intCast(y);
                p *= id;
                p += self.serial;
                p *= id;
                p = @divTrunc(p, 100);
                p = @mod(p, 10);
                p -= 5;
                self.sum[y][x] = p + self.sum[y - 1][x] + self.sum[y][x - 1] - self.sum[y - 1][x - 1];
            }
        }
    }

    fn resetBest(self: *Charge) void {
        self.best_power = 0;
        self.best_x = 0;
        self.best_y = 0;
        self.best_size = 0;
    }

    fn computeForSize(self: *Charge, size: usize) void {
        for (size..SIZE + 1) |y| {
            for (size..SIZE + 1) |x| {
                const total = self.sum[y][x] - self.sum[y - size][x] - self.sum[y][x - size] + self.sum[y - size][x - size];
                if (self.best_power < total) {
                    self.best_power = total;
                    self.best_x = @intCast(x);
                    self.best_y = @intCast(y);
                    self.best_size = @intCast(size);
                }
            }
        }
    }
};

test "sample part 1 case A" {
    const data =
        \\18
    ;

    var charge = Charge.init();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try charge.addLine(line);
    }

    const best = try charge.findBestForSize(3);
    const expected = "33,45";
    try testing.expectEqualStrings(expected, best);
}

test "sample part 1 case B" {
    const data =
        \\42
    ;

    var charge = Charge.init();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try charge.addLine(line);
    }

    const best = try charge.findBestForSize(3);
    const expected = "21,61";
    try testing.expectEqualStrings(expected, best);
}

test "sample part 2 case A" {
    const data =
        \\18
    ;

    var charge = Charge.init();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try charge.addLine(line);
    }

    const best = try charge.findBestForAnySize();
    const expected = "90,269,16";
    try testing.expectEqualStrings(expected, best);
}

test "sample part 2 case B" {
    const data =
        \\42
    ;

    var charge = Charge.init();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try charge.addLine(line);
    }

    const best = try charge.findBestForAnySize();
    const expected = "232,251,12";
    try testing.expectEqualStrings(expected, best);
}
