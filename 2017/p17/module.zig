const std = @import("std");
const testing = std.testing;

pub const Spinlock = struct {
    const SIZE = 2018;

    size: usize,
    pos: usize,
    skip: usize,
    buffer: [SIZE]usize,

    pub fn init() Spinlock {
        var self = Spinlock{
            .size = 1,
            .pos = 0,
            .skip = 0,
            .buffer = undefined,
        };
        self.buffer[0] = 0;
        return self;
    }

    pub fn addLine(self: *Spinlock, line: []const u8) !void {
        self.skip = try std.fmt.parseUnsigned(usize, line, 10);
    }

    pub fn getNumberAfterLast(self: *Spinlock, times: usize) !usize {
        for (0..times) |_| {
            self.next();
        }
        return self.buffer[self.pos + 1];
    }

    pub fn getNumberAfterZero(self: *Spinlock, times: usize) !usize {
        var num: usize = 0;
        var pos: usize = 0;
        for (0..times) |step| {
            const div = step + 1;
            pos = (pos + self.skip) % div + 1;
            if (pos == 1) num = div; // remember anything in position 1
        }
        return num;
    }

    fn next(self: *Spinlock) void {
        var pos: usize = self.pos;
        pos += self.skip;
        pos %= self.size;
        var p: usize = self.size - 1;
        while (p > pos) : (p -= 1) {
            self.buffer[p + 1] = self.buffer[p];
        }
        self.pos = pos + 1;
        self.buffer[self.pos] = self.size;
        self.size += 1;
    }
};

test "sample part 1" {
    const data =
        \\3
    ;

    var spinlock = Spinlock.init();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try spinlock.addLine(line);
    }

    const number = try spinlock.getNumberAfterLast(2017);
    const expected = @as(usize, 638);
    try testing.expectEqual(expected, number);
}
