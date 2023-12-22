const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Stack = struct {
    const V3 = Math.Vector(isize, 3);
    const V2 = Math.Vector(isize, 2);

    const Brick = struct {
        pos: usize,
        v0: V3,
        v1: V3,
        supported: std.AutoHashMap(usize, void),
        supports: std.AutoHashMap(usize, void),

        pub fn init(allocator: Allocator, pos: usize, v0: V3, v1: V3) Brick {
            const self = Brick{
                .pos = pos,
                .v0 = v0,
                .v1 = v1,
                .supported = std.AutoHashMap(usize, void).init(allocator),
                .supports = std.AutoHashMap(usize, void).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Brick) void {
            self.supports.deinit();
            self.supported.deinit();
        }

        pub fn lessThan(context: void, l: Brick, r: Brick) bool {
            return V3.cmp(context, l.v0, r.v0) == std.math.Order.lt;
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
    tops: std.AutoHashMap(V2, Top),

    pub fn init(allocator: Allocator) Stack {
        var self = Stack{
            .allocator = allocator,
            .processed = false,
            .bricks = std.ArrayList(Brick).init(allocator),
            .tops = std.AutoHashMap(V2, Top).init(allocator),
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
        var v0: V3 = undefined;
        var it_brick = std.mem.tokenizeScalar(u8, line, '~');
        while (it_brick.next()) |brick_chunk| : (brick_count += 1) {
            var v1: V3 = undefined;
            var pos_cnt: usize = 0;
            var it_pos = std.mem.tokenizeScalar(u8, brick_chunk, ',');
            while (it_pos.next()) |str| : (pos_cnt += 1) {
                const n = try std.fmt.parseInt(isize, str, 10);
                switch (pos_cnt) {
                    0...2 => |i| v1.v[i] = n,
                    else => unreachable,
                }
            }
            switch (brick_count) {
                0 => v0 = v1,
                1 => {
                    const brick = Brick.init(self.allocator, self.bricks.items.len, v0, v1);
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
        for (self.bricks.items, 0..) |brick, bpos| {
            const sub = V3.sub(brick.v1, brick.v0);
            if (sub.v[0] < 0 or sub.v[1] < 0 or sub.v[2] < 0) unreachable;

            if (sub.v[0] == 0 and sub.v[1] == 0) {
                const p = V2.copy(&brick.v0.v);
                var entry = self.tops.getEntry(p);
                var nh: usize = @intCast(sub.v[2]);
                nh += 1;
                if (entry) |e| {
                    nh += e.value_ptr.*.height;
                    try self.updateSupport(bpos, e.value_ptr.*.brick);
                }
                try self.tops.put(p, Top.init(nh, bpos));
                continue;
            }

            if (sub.v[2] > 1) unreachable;

            if (sub.v[0] > 0) {
                if (sub.v[1] > 0) unreachable;
                try self.findAndUpdateMax(bpos, V2.unit(0));
                continue;
            }

            if (sub.v[1] > 0) {
                if (sub.v[0] > 0) unreachable;
                try self.findAndUpdateMax(bpos, V2.unit(1));
                continue;
            }

            unreachable;
        }
    }

    fn findAndUpdateMax(self: *Stack, bpos: usize, delta: V2) !void {
        const brick = self.bricks.items[bpos];
        var max = Top.init(0, std.math.maxInt(isize));
        for (0..2) |pass| {
            var p = V2.copy(&brick.v0.v);
            while (p.v[0] <= brick.v1.v[0] and p.v[1] <= brick.v1.v[1]) {
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
                p = V2.add(p, delta);
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
