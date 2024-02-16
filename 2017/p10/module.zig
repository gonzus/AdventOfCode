const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Knot = struct {
    const SIZE = 256;

    allocator: Allocator,
    advanced: bool,
    lengths: std.ArrayList(usize),
    numbers: [SIZE]usize,
    size: usize,
    pos: usize,
    skip: usize,
    buf: [32]u8,

    pub fn init(allocator: Allocator, size: usize, advanced: bool) Knot {
        var self = Knot{
            .allocator = allocator,
            .advanced = advanced,
            .lengths = std.ArrayList(usize).init(allocator),
            .numbers = undefined,
            .size = undefined,
            .pos = 0,
            .skip = 0,
            .buf = undefined,
        };
        self.size = if (size == 0) SIZE else size;
        for (0..self.size) |p| {
            self.numbers[p] = p;
        }
        return self;
    }

    pub fn deinit(self: *Knot) void {
        self.lengths.deinit();
    }

    pub fn addLine(self: *Knot, line: []const u8) !void {
        if (self.advanced) {
            for (line) |c| {
                try self.lengths.append(c);
            }
        } else {
            var it = std.mem.tokenizeAny(u8, line, ", ");
            while (it.next()) |chunk| {
                const num = try std.fmt.parseUnsigned(usize, chunk, 10);
                try self.lengths.append(num);
            }
        }
    }

    pub fn show(self: Knot) void {
        for (0..self.size) |n| {
            if (n == self.pos) {
                std.debug.print(" [{}]", .{self.numbers[n]});
            } else {
                std.debug.print("  {} ", .{self.numbers[n]});
            }
        }
        std.debug.print("\n", .{});
    }

    pub fn getProductFirstTwo(self: *Knot) !usize {
        return try self.getProductFirstN(2);
    }

    pub fn getFinalHash(self: *Knot) ![]const u8 {
        const extra = [_]usize{ 17, 31, 73, 47, 23 };
        for (extra) |e| {
            try self.lengths.append(e);
        }
        for (0..64) |_| {
            try self.hash();
        }
        for (0..16) |r| {
            var v: usize = 0;
            for (0..16) |c| {
                v ^= self.numbers[r * 16 + c];
            }
            _ = try std.fmt.bufPrint(self.buf[2 * r ..], "{x:0>2}", .{v});
        }
        return self.buf[0..32];
    }

    fn getProductFirstN(self: *Knot, n: usize) !usize {
        try self.hash();
        var prod: usize = 1;
        for (0..n) |p| {
            prod *= self.numbers[p];
        }
        return prod;
    }

    fn hash(self: *Knot) !void {
        for (self.lengths.items) |length| {
            const middle = length / 2;
            for (0..middle) |pos| {
                const s = (self.pos + pos) % self.size;
                const t = (self.pos + length - pos - 1) % self.size;
                std.mem.swap(usize, &self.numbers[s], &self.numbers[t]);
            }
            self.pos = (self.pos + length + self.skip) % self.size;
            self.skip += 1;
        }
    }
};

test "sample part 1" {
    const data =
        \\3, 4, 1, 5
    ;

    var knot = Knot.init(testing.allocator, 5, false);
    defer knot.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try knot.addLine(line);
    }

    const product = try knot.getProductFirstTwo();
    const expected = @as(usize, 12);
    try testing.expectEqual(expected, product);
}
