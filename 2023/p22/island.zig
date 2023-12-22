const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Stack = struct {
    const Pos = struct {
        x: isize,
        y: isize,
        z: isize,

        pub fn init(x: isize, y: isize, z: isize) Pos {
            return Pos{ .x = x, .y = y, .z = z };
        }

        pub fn initFromUnsigned(x: usize, y: usize, z: usize) Pos {
            return Pos{ .x = @intCast(x), .y = @intCast(y), .z = @intCast(z) };
        }

        pub fn cmp(_: void, l: Pos, r: Pos) std.math.Order {
            if (l.z < r.z) return std.math.Order.lt;
            if (l.z > r.z) return std.math.Order.gt;
            if (l.y < r.y) return std.math.Order.lt;
            if (l.y > r.y) return std.math.Order.gt;
            if (l.x < r.x) return std.math.Order.lt;
            if (l.x > r.x) return std.math.Order.gt;
            return std.math.Order.eq;
        }

        pub fn format(
            pos: Pos,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("({d},{d},{d})", .{ pos.x, pos.y, pos.z });
        }
    };

    const P2 = struct {
        x: isize,
        y: isize,

        pub fn init(x: isize, y: isize) P2 {
            return P2{ .x = x, .y = y };
        }

        pub fn cmp(_: void, l: Pos, r: Pos) std.math.Order {
            if (l.y < r.y) return std.math.Order.lt;
            if (l.y > r.y) return std.math.Order.gt;
            if (l.x < r.x) return std.math.Order.lt;
            if (l.x > r.x) return std.math.Order.gt;
            return std.math.Order.eq;
        }

        pub fn format(
            p2: P2,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("({d},{d})", .{ p2.x, p2.y });
        }
    };
    const Brick = struct {
        pos: usize,
        p0: Pos,
        p1: Pos,
        supported: std.AutoHashMap(usize, void),
        supports: std.AutoHashMap(usize, void),
        total: std.AutoHashMap(usize, void),

        pub fn init(allocator: Allocator, pos: usize, p0: Pos, p1: Pos) Brick {
            const self = Brick{
                .pos = pos,
                .p0 = p0,
                .p1 = p1,
                .supported = std.AutoHashMap(usize, void).init(allocator),
                .supports = std.AutoHashMap(usize, void).init(allocator),
                .total = std.AutoHashMap(usize, void).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Brick) void {
            self.total.deinit();
            self.supports.deinit();
            self.supported.deinit();
        }

        pub fn lessThan(_: void, l: Brick, r: Brick) bool {
            return l.p0.z < r.p0.z;
        }

        pub fn format(
            brick: Brick,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("{}~{}", .{ brick.p0, brick.p1 });
        }
    };

    const Top = struct {
        height: usize,
        brick: usize,

        pub fn init(height: usize, brick: usize) Top {
            return Top{ .height = height, .brick = brick };
        }
    };

    allocator: Allocator,
    processed: bool,
    bricks: std.ArrayList(Brick),
    tops: std.AutoHashMap(P2, Top),

    pub fn init(allocator: Allocator) Stack {
        var self = Stack{
            .allocator = allocator,
            .processed = false,
            .bricks = std.ArrayList(Brick).init(allocator),
            .tops = std.AutoHashMap(P2, Top).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Stack) void {
        self.tops.deinit();
        for (self.bricks.items) |*brick| {
            brick.deinit();
        }
        self.bricks.deinit();
    }

    pub fn addLine(self: *Stack, line: []const u8) !void {
        var brick_count: usize = 0;
        var p0: Pos = undefined;
        var it_brick = std.mem.tokenizeScalar(u8, line, '~');
        while (it_brick.next()) |brick_chunk| : (brick_count += 1) {
            var p1: Pos = undefined;
            var pos_cnt: usize = 0;
            var it_pos = std.mem.tokenizeScalar(u8, brick_chunk, ',');
            while (it_pos.next()) |str| : (pos_cnt += 1) {
                const n = try std.fmt.parseInt(isize, str, 10);
                switch (pos_cnt) {
                    0 => p1.x = n,
                    1 => p1.y = n,
                    2 => p1.z = n,
                    else => unreachable,
                }
            }
            switch (brick_count) {
                0 => p0 = p1,
                1 => {
                    const brick = Brick.init(self.allocator, self.bricks.items.len, p0, p1);
                    try self.bricks.append(brick);
                },
                else => unreachable,
            }
        }
    }

    pub fn getBricksToDisintegrate(self: *Stack) !usize {
        try self.processBricks();
        var count: usize = 0;
        for (self.bricks.items) |brick| {
            var stable = true;
            var it = brick.supports.keyIterator();
            while (it.next()) |s| {
                const other = self.bricks.items[s.*];
                if (other.supported.count() == 1) {
                    stable = false;
                    break;
                }
            }
            if (!stable) continue;
            count += 1;
        }
        return count;
    }

    pub fn getChainReaction(self: *Stack) !usize {
        try self.processBricks();
        var count: usize = 0;
        for (self.bricks.items, 0..) |_, pos| {
            count += try self.propagateFromPos(pos);
        }
        return count;
    }

    fn processBricks(self: *Stack) !void {
        if (self.processed) return;
        self.processed = true;
        std.sort.heap(Brick, self.bricks.items, {}, Brick.lessThan);
        for (self.bricks.items, 0..) |*brick, bpos| {
            const dx = brick.*.p1.x - brick.*.p0.x;
            const dy = brick.*.p1.y - brick.*.p0.y;
            const dz = brick.*.p1.z - brick.*.p0.z;
            if (dx < 0 or dy < 0 or dz < 0) unreachable;
            if (dx == 0 and dy == 0) {
                const p = P2.init(brick.*.p0.x, brick.*.p0.y);
                var entry = self.tops.getEntry(p);
                var nh: usize = @intCast(dz);
                nh += 1;
                if (entry) |e| {
                    nh += e.value_ptr.*.height;
                    try self.updateSupport(bpos, e.value_ptr.*.brick);
                }
                try self.tops.put(p, Top.init(nh, bpos));
                continue;
            }
            if (dx > 0) {
                if (dy > 0) unreachable;
                if (dz > 1) unreachable;
                try self.findAndUpdateMax(bpos, 1, 0);
                continue;
            }
            if (dy > 0) {
                if (dx > 0) unreachable;
                if (dz > 1) unreachable;
                try self.findAndUpdateMax(bpos, 0, 1);
                continue;
            }
            unreachable;
        }
    }

    fn findAndUpdateMax(self: *Stack, bpos: usize, dx: isize, dy: isize) !void {
        const brick = self.bricks.items[bpos];
        var max = Top.init(0, std.math.maxInt(isize));
        for (0..2) |pass| {
            var x = brick.p0.x;
            var y = brick.p0.y;
            while (x <= brick.p1.x and y <= brick.p1.y) {
                const p = P2.init(x, y);
                var below = self.tops.get(p);
                if (below) |b| {
                    if (pass == 0) {
                        if (max.height < b.height) {
                            max = b;
                        }
                    }
                    if (pass == 1) {
                        if (b.height == max.height) {
                            try self.updateSupport(bpos, b.brick);
                        }
                    }
                }
                if (pass == 1) {
                    try self.tops.put(p, Top.init(max.height + 1, bpos));
                }
                x += dx;
                y += dy;
            }
        }
    }

    fn updateSupport(self: *Stack, b0: usize, b1: usize) !void {
        _ = try self.bricks.items[b0].supported.getOrPut(b1);
        _ = try self.bricks.items[b1].supports.getOrPut(b0);
    }

    fn propagateFromPos(self: *Stack, start: usize) !usize {
        var seen = std.AutoHashMap(usize, void).init(self.allocator);
        defer seen.deinit();
        try seen.put(start, {});
        while (true) {
            const seen_before = seen.count();
            for (start..self.bricks.items.len) |pos| {
                var brick = self.bricks.items[pos];
                var it_supports = brick.supports.keyIterator();
                while (it_supports.next()) |s| {
                    const supports = self.bricks.items[s.*];
                    var stable = true;
                    var it_supported = supports.supported.keyIterator();
                    while (it_supported.next()) |t| {
                        if (seen.contains(t.*)) continue;
                        stable = false;
                        break;
                    }
                    if (!stable) continue;
                    try seen.put(s.*, {});
                }
            }
            const seen_after = seen.count();
            if (seen_before == seen_after) break;
        }
        return seen.count() - 1;
    }
};

test "sample simple part 1" {
    const data =
        \\1,0,1~1,2,1
        \\0,0,2~2,0,2
        \\0,2,3~2,2,3
        \\0,0,4~0,2,4
        \\2,0,5~2,2,5
        \\0,1,6~2,1,6
        \\1,1,8~1,1,9
    ;
    std.debug.print("\n", .{});

    var stack = Stack.init(std.testing.allocator);
    defer stack.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stack.addLine(line);
    }

    const count = try stack.getBricksToDisintegrate();
    const expected = @as(usize, 5);
    try testing.expectEqual(expected, count);
}

test "sample simple part 2" {
    const data =
        \\1,0,1~1,2,1
        \\0,0,2~2,0,2
        \\0,2,3~2,2,3
        \\0,0,4~0,2,4
        \\2,0,5~2,2,5
        \\0,1,6~2,1,6
        \\1,1,8~1,1,9
    ;
    std.debug.print("\n", .{});

    var stack = Stack.init(std.testing.allocator);
    defer stack.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stack.addLine(line);
    }

    const count = try stack.getChainReaction();
    const expected = @as(usize, 7);
    try testing.expectEqual(expected, count);
}
