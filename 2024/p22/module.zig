const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const CHANGES = 2000;

    const Diffs = struct {
        const SIZE = 4;
        const NORMALIZE_DIFF = 9;

        val: [SIZE]isize,
        len: usize,
        pos: usize,

        pub fn init() Diffs {
            const self: Diffs = undefined;
            return self;
        }

        pub fn reset(self: *Diffs) void {
            self.len = 0;
            self.pos = 0;
        }

        pub fn valid(self: Diffs) bool {
            return self.len == SIZE;
        }

        pub fn register(self: *Diffs, l: usize, r: usize) usize {
            const lm: usize = l % 10;
            const rm: usize = r % 10;
            var delta: isize = 0;
            delta += @intCast(rm);
            delta -= @intCast(lm);
            self.val[self.pos] = delta;
            self.pos += 1;
            self.pos %= SIZE;
            if (self.len < SIZE) self.len += 1;
            return rm;
        }

        pub fn encode(self: *Diffs) usize {
            var code: usize = 0;
            var p: usize = self.pos;
            for (0..SIZE) |_| {
                code *= 100;
                code += @intCast(self.val[p] + NORMALIZE_DIFF);
                p += 1;
                p %= SIZE;
            }
            return code;
        }
    };

    seeds: std.ArrayList(usize),
    seen: std.AutoHashMap(usize, void),
    total: std.AutoHashMap(usize, usize),

    pub fn init(allocator: Allocator) Module {
        return .{
            .seeds = std.ArrayList(usize).init(allocator),
            .seen = std.AutoHashMap(usize, void).init(allocator),
            .total = std.AutoHashMap(usize, usize).init(allocator),
        };
    }

    pub fn deinit(self: *Module) void {
        self.total.deinit();
        self.seen.deinit();
        self.seeds.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        const seed = try std.fmt.parseUnsigned(usize, line, 10);
        try self.seeds.append(seed);
    }

    pub fn getSumSecret(self: *Module) !usize {
        var sum: usize = 0;
        for (self.seeds.items) |seed| {
            var num: usize = seed;
            for (0..CHANGES) |_| {
                num = computeNext(num);
            }
            sum += num;
        }
        return sum;
    }

    pub fn getMostBananas(self: *Module) !usize {
        self.total.clearRetainingCapacity();
        var diffs = Diffs.init();
        for (self.seeds.items) |seed| {
            self.seen.clearRetainingCapacity();
            diffs.reset();
            var last: usize = seed;
            for (0..CHANGES) |_| {
                const num = computeNext(last);
                defer last = num;

                const bananas = diffs.register(last, num);
                if (!diffs.valid()) continue;

                const code = diffs.encode();
                const rs = try self.seen.getOrPut(code);
                if (rs.found_existing) continue;

                const rt = try self.total.getOrPut(code);
                if (!rt.found_existing) {
                    rt.value_ptr.* = 0;
                }
                rt.value_ptr.* += bananas;
            }
        }

        var bananas: usize = 0;
        var it = self.total.valueIterator();
        while (it.next()) |b| {
            if (bananas < b.*) bananas = b.*;
        }
        return bananas;
    }

    fn mix(num: usize, val: usize) usize {
        return val ^ num;
    }

    fn prune(num: usize) usize {
        return num & ((1 << 24) - 1); // % 16777216;
    }

    fn computeNext(num: usize) usize {
        var copy = num;
        var val: usize = 0;

        val = copy << 6; // * 64;
        val = mix(copy, val);
        copy = prune(val);

        val = copy >> 5; // / 32;
        val = mix(copy, val);
        copy = prune(val);

        val = copy << 11; // * 2048;
        val = mix(copy, val);
        copy = prune(val);

        return copy;
    }
};

test "sample part 1" {
    const data =
        \\1
        \\10
        \\100
        \\2024
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const sum = try module.getSumSecret();
    const expected = @as(usize, 37327623);
    try testing.expectEqual(expected, sum);
}

test "sample part 2" {
    const data =
        \\1
        \\2
        \\3
        \\2024
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const sum = try module.getMostBananas();
    const expected = @as(usize, 23);
    try testing.expectEqual(expected, sum);
}
