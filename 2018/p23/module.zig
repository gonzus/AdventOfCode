const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Cave = struct {
    const Pos = Math.Vector(isize, 3);

    const Box = struct {
        p: [2]Pos,

        pub fn init(p0: Pos, p1: Pos) Box {
            return .{
                .p = [_]Pos{ p0, p1 },
            };
        }

        pub fn makeBoundingBox(size: usize) Box {
            const pos_size: isize = @intCast(size);
            const neg_size: isize = -1 * pos_size;
            return Box.init(
                Pos.copy(&[_]isize{ neg_size, neg_size, neg_size }),
                Pos.copy(&[_]isize{ pos_size, pos_size, pos_size }),
            );
        }
    };

    const Bot = struct {
        pos: Pos,
        range: usize,

        pub fn init(x: isize, y: isize, z: isize, range: usize) Bot {
            return .{
                .pos = Pos.copy(&[_]isize{ x, y, z }),
                .range = range,
            };
        }

        pub fn intersectsBox(self: Bot, box: Box) bool {
            var r: usize = 0;
            for (0..3) |d| {
                const l = box.p[0].v[d];
                const h = box.p[1].v[d] - 1;
                const diff: usize = @intCast(h - l);
                r += @abs(self.pos.v[d] - l);
                r += @abs(self.pos.v[d] - h);
                r -= diff;
            }
            r /= 2;
            return r <= self.range;
        }
    };

    allocator: Allocator,
    bots: std.ArrayList(Bot),

    pub fn init(allocator: Allocator) Cave {
        return .{
            .allocator = allocator,
            .bots = std.ArrayList(Bot).init(allocator),
        };
    }

    pub fn deinit(self: *Cave) void {
        self.bots.deinit();
    }

    pub fn addLine(self: *Cave, line: []const u8) !void {
        var it = std.mem.tokenizeAny(u8, line, " =<>,");
        _ = it.next();
        const x = try std.fmt.parseInt(isize, it.next().?, 10);
        const y = try std.fmt.parseInt(isize, it.next().?, 10);
        const z = try std.fmt.parseInt(isize, it.next().?, 10);
        _ = it.next();
        const r = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        try self.bots.append(Bot.init(x, y, z, r));
    }

    pub fn show(self: Cave) void {
        std.debug.print("Cave with {} bots\n", .{self.bots.items.len});
        for (self.bots.items) |bot| {
            std.debug.print("  {} => {}\n", .{ bot.pos, bot.range });
        }
    }

    pub fn getCountInRangeForLargestRange(self: Cave) !usize {
        var count: usize = 0;
        var top_range: usize = 0;
        var top_pos: usize = 0;
        for (self.bots.items, 0..) |bot, pos| {
            if (top_range >= bot.range) continue;
            top_range = bot.range;
            top_pos = pos;
        }
        for (self.bots.items) |bot| {
            if (bot.pos.manhattanDist(self.bots.items[top_pos].pos) > top_range) continue;
            count += 1;
        }
        return count;
    }

    pub fn findDistanceToBestPosition(self: Cave) !usize {
        const origin = Pos.copy(&[_]isize{ 0, 0, 0 });
        return try self.findDistanceToBestPositionFrom(origin);
    }

    fn intersectCount(self: Cave, box: Box) usize {
        var count: usize = 0;
        for (self.bots.items) |bot| {
            if (!bot.intersectsBox(box)) continue;
            count += 1;
        }
        return count;
    }

    const State = struct {
        count: usize,
        size: usize,
        dist: usize,
        box: Box,

        pub fn init(count: usize, size: usize, dist: usize, box: Box) State {
            return .{ .count = count, .size = size, .dist = dist, .box = box };
        }

        fn cmp(_: void, l: State, r: State) std.math.Order {
            // count desc
            if (l.count < r.count) return .gt;
            if (l.count > r.count) return .lt;
            // size desc
            if (l.size < r.size) return .gt;
            if (l.size > r.size) return .lt;
            // dist asc
            if (l.dist < r.dist) return .lt;
            if (l.dist > r.dist) return .gt;
            return .eq;
        }
    };

    fn findDistanceToBestPositionFrom(self: Cave, source: Pos) !usize {
        const Octants = [_]Pos{
            Pos.copy(&[_]isize{ 0, 0, 0 }),
            Pos.copy(&[_]isize{ 0, 0, 1 }),
            Pos.copy(&[_]isize{ 0, 1, 0 }),
            Pos.copy(&[_]isize{ 0, 1, 1 }),
            Pos.copy(&[_]isize{ 1, 0, 0 }),
            Pos.copy(&[_]isize{ 1, 0, 1 }),
            Pos.copy(&[_]isize{ 1, 1, 0 }),
            Pos.copy(&[_]isize{ 1, 1, 1 }),
        };

        var largest_coord: usize = 0;
        for (self.bots.items) |bot| {
            for (0..3) |d| {
                const coord: usize = @abs(bot.pos.v[d]) + bot.range;
                if (largest_coord > coord) continue;
                largest_coord = coord;
            }
        }

        var bounding_size: usize = 1;
        while (bounding_size <= largest_coord) {
            bounding_size *= 2;
        }

        const PQ = std.PriorityQueue(State, void, State.cmp);
        var heap = PQ.init(self.allocator, {});
        defer heap.deinit();

        const initial_box = Box.makeBoundingBox(bounding_size);
        try heap.add(State.init(self.bots.items.len, 2 * bounding_size, Math.INFINITY, initial_box));
        while (heap.count() != 0) {
            const current = heap.remove();
            if (current.size == 1) {
                return current.dist;
            }

            const new_size = current.size / 2;
            const size: isize = @intCast(new_size);
            for (Octants) |octant| {
                var p0 = Pos.init();
                var p1 = Pos.init();
                for (0..3) |d| {
                    p0.v[d] = current.box.p[0].v[d] + size * octant.v[d];
                    p1.v[d] = p0.v[d] + size;
                }
                const new_box = Box.init(p0, p1);
                const new_count = self.intersectCount(new_box);
                const new_dist = p0.manhattanDist(source);
                try heap.add(State.init(new_count, new_size, new_dist, new_box));
            }
        }

        return 0;
    }
};

test "sample part 1" {
    const data =
        \\pos=<0,0,0>, r=4
        \\pos=<1,0,0>, r=1
        \\pos=<4,0,0>, r=3
        \\pos=<0,2,0>, r=1
        \\pos=<0,5,0>, r=3
        \\pos=<0,0,3>, r=1
        \\pos=<1,1,1>, r=1
        \\pos=<1,1,2>, r=1
        \\pos=<1,3,1>, r=1
    ;

    var cave = Cave.init(std.testing.allocator);
    defer cave.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cave.addLine(line);
    }
    // cave.show();

    const count = try cave.getCountInRangeForLargestRange();
    const expected = @as(usize, 7);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\pos=<10,12,12>, r=2
        \\pos=<12,14,12>, r=2
        \\pos=<16,12,12>, r=4
        \\pos=<14,14,14>, r=6
        \\pos=<50,50,50>, r=200
        \\pos=<10,10,10>, r=5
    ;

    var cave = Cave.init(std.testing.allocator);
    defer cave.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cave.addLine(line);
    }
    // cave.show();

    const count = try cave.findDistanceToBestPosition();
    const expected = @as(usize, 36);
    try testing.expectEqual(expected, count);
}
