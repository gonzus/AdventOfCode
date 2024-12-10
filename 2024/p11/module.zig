const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const INFINITY = std.math.maxInt(usize);

    // key observation: blinking results don't depend on the order of the stones
    // therefore we can minimize the data by sorting and compressing the stone counts
    const Stone = struct {
        num: usize,
        cnt: usize,

        pub fn init(num: usize, cnt: usize) Stone {
            return .{ .num = num, .cnt = cnt };
        }

        pub fn lessThan(_: void, l: Stone, r: Stone) bool {
            return l.num < r.num;
        }
    };

    stones: std.ArrayList(Stone),
    tmp: std.ArrayList(Stone),

    pub fn init(allocator: Allocator) Module {
        return .{
            .stones = std.ArrayList(Stone).init(allocator),
            .tmp = std.ArrayList(Stone).init(allocator),
        };
    }

    pub fn deinit(self: *Module) void {
        self.tmp.deinit();
        self.stones.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        while (it.next()) |chunk| {
            const num = try std.fmt.parseUnsigned(usize, chunk, 10);
            try self.stones.append(Stone.init(num, 1));
        }
    }

    pub fn countStonesAfterBlinks(self: *Module, blinks: usize) !usize {
        for (0..blinks) |_| {
            try self.blink();
        }
        var count: usize = 0;
        for (self.stones.items) |s| {
            count += s.cnt;
        }
        return count;
    }

    fn blink(self: *Module) !void {
        // expand stones into tmp according to rules
        self.tmp.clearRetainingCapacity();
        for (self.stones.items) |s| {
            if (s.num == 0) {
                try self.tmp.append(Stone.init(1, s.cnt));
                continue;
            }
            const digits = std.math.log10(s.num) + 1;
            if (digits % 2 == 0) {
                const pow = std.math.pow(usize, 10, digits / 2);
                const l = s.num / pow;
                const r = s.num % pow;
                try self.tmp.append(Stone.init(l, s.cnt));
                try self.tmp.append(Stone.init(r, s.cnt));
                continue;
            }
            const n = s.num * 2024;
            try self.tmp.append(Stone.init(n, s.cnt));
        }

        // sort expanded stones in tmp
        std.sort.heap(Stone, self.tmp.items, {}, Stone.lessThan);

        // compress sorted results in tmp back into stones
        self.stones.clearRetainingCapacity();
        var last: usize = INFINITY;
        for (self.tmp.items) |s| {
            if (last != INFINITY and self.stones.items[last].num == s.num) {
                self.stones.items[last].cnt += s.cnt;
                continue;
            }
            last = self.stones.items.len;
            try self.stones.append(s);
        }
    }
};

test "sample part 1 example 1" {
    const data =
        \\0 1 10 99 999
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.countStonesAfterBlinks(1);
    const expected = @as(usize, 7);
    try testing.expectEqual(expected, count);
}

test "sample part 1 example 2" {
    const data =
        \\125 17
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.countStonesAfterBlinks(6);
    const expected = @as(usize, 22);
    try testing.expectEqual(expected, count);
}

test "sample part 1 example 3" {
    const data =
        \\125 17
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.countStonesAfterBlinks(25);
    const expected = @as(usize, 55312);
    try testing.expectEqual(expected, count);
}
