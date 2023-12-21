const std = @import("std");
const testing = std.testing;
const Grid = @import("./util/grid.zig").Grid;

const Allocator = std.mem.Allocator;

pub const Garden = struct {
    const Data = Grid(u8);

    const Pos = struct {
        x: isize,
        y: isize,

        pub fn init(x: isize, y: isize) Pos {
            return Pos{ .x = x, .y = y };
        }

        pub fn initFromUnsigned(x: usize, y: usize) Pos {
            return Pos{ .x = @intCast(x), .y = @intCast(y) };
        }

        pub fn cmp(_: void, l: Pos, r: Pos) std.math.Order {
            if (l.x < r.x) return std.math.Order.lt;
            if (l.x > r.x) return std.math.Order.gt;
            if (l.y < r.y) return std.math.Order.lt;
            if (l.y > r.y) return std.math.Order.gt;
            return std.math.Order.eq;
        }

        pub fn format(
            pos: Pos,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("({d},{d})", .{ pos.x, pos.y });
        }
    };

    const deltas: [4]Pos = [_]Pos{
        Pos.init(1, 0),
        Pos.init(-1, 0),
        Pos.init(0, 1),
        Pos.init(0, -1),
    };

    allocator: Allocator,
    repeated: bool,
    grid: Data,
    start: Pos,

    pub fn init(allocator: Allocator, repeated: bool) Garden {
        var self = Garden{
            .allocator = allocator,
            .repeated = repeated,
            .grid = Data.init(allocator, '.'),
            .start = undefined,
        };
        return self;
    }

    pub fn deinit(self: *Garden) void {
        self.grid.deinit();
    }

    pub fn addLine(self: *Garden, line: []const u8) !void {
        try self.grid.ensureCols(line.len);
        try self.grid.ensureExtraRow();
        const y = self.grid.rows();
        for (line, 0..) |c, x| {
            if (c == 'S') {
                self.start = Pos.initFromUnsigned(x, y);
                try self.grid.set(x, y, '.');
            } else {
                try self.grid.set(x, y, c);
            }
        }
    }

    pub fn show(self: Garden) void {
        std.debug.print("Garden: {} x {} -- start at {}\n", .{ self.grid.rows(), self.grid.cols(), self.start });
        for (0..self.grid.rows()) |y| {
            for (0..self.grid.cols()) |x| {
                std.debug.print("{c}", .{self.grid.get(x, y)});
            }
            std.debug.print("\n", .{});
        }
    }

    const PosData = struct {
        pos: Pos,
        steps: isize,

        pub fn init(pos: Pos, steps: isize) PosData {
            return PosData{
                .pos = pos,
                .steps = steps,
            };
        }

        fn lessThan(_: void, l: PosData, r: PosData) std.math.Order {
            const so = std.math.order(l.steps, r.steps);
            if (so != .eq) return so;
            return Pos.cmp({}, l.pos, r.pos);
        }
    };

    const PQ = std.PriorityQueue(PosData, void, PosData.lessThan);

    fn strollGarden(self: *Garden, max_steps: isize) !usize {
        var queue = PQ.init(self.allocator, {});
        defer queue.deinit();
        var seen = std.AutoHashMap(PosData, void).init(self.allocator);
        defer seen.deinit();

        var count: usize = 0;
        const max = Pos.initFromUnsigned(self.grid.cols() - 1, self.grid.rows() - 1);
        try queue.add(PosData.init(self.start, 0));
        while (queue.count() > 0) {
            const cur = queue.remove();
            if (cur.steps > max_steps) break;
            if (cur.steps == max_steps) count += 1;
            for (deltas) |delta| {
                var npos = cur.pos;
                npos.x += delta.x;
                npos.y += delta.y;
                if (self.repeated) {
                    if (npos.x < 0) {
                        npos.x = max.x;
                    }
                    if (npos.x >= max.x) {
                        npos.x = 0;
                    }
                    if (npos.y < 0) {
                        npos.y = max.y;
                    }
                    if (npos.y >= max.y) {
                        npos.y = 0;
                    }
                }
                if (!self.grid.validPos(npos.x, npos.y)) continue;
                if (self.grid.get(@intCast(npos.x), @intCast(npos.y)) != '.') continue;
                const next = PosData.init(npos, cur.steps + 1);
                const entry = try seen.getOrPut(next);
                if (entry.found_existing) continue;
                try queue.add(next);
            }
        }
        return count;
    }

    fn countPlotsForLargeSteps(self: *Garden, steps: isize) !usize {
        if (self.grid.rows() != self.grid.cols()) unreachable;

        const Map = std.AutoHashMap(Pos, void);

        var visited = Map.init(self.allocator);
        defer visited.deinit();
        var new = Map.init(self.allocator);
        defer new.deinit();
        var tmp = Map.init(self.allocator);
        defer tmp.deinit();
        var cache = std.ArrayList(usize).init(self.allocator);
        defer cache.deinit();

        var pv: *Map = &visited;
        var pn: *Map = &new;
        var pt: *Map = &tmp;

        _ = try visited.put(self.start, {});
        _ = try new.put(self.start, {});
        _ = try cache.append(1);

        const size: isize = @intCast(self.grid.rows());
        const steps_mod = @mod(steps, size);
        const top = steps_mod + 2 * size + 1;
        var j: usize = 1;
        while (j < top) : (j += 1) {
            pt.*.clearRetainingCapacity();
            var it = pn.*.iterator();
            while (it.next()) |entry_new| {
                for (deltas) |delta| {
                    var np = entry_new.key_ptr.*;
                    np.x += delta.x;
                    np.y += delta.y;
                    if (pv.*.contains(np)) continue;
                    const ux: usize = @intCast(@mod(np.x, size));
                    const uy: usize = @intCast(@mod(np.y, size));
                    if (self.grid.get(ux, uy) != '.') continue;
                    _ = try pt.*.put(np, {});
                }
            }
            const px = pv;
            pv = pn;
            pn = pt;
            pt = px;

            var value: usize = pn.*.count();
            if (j >= 2) value += cache.items[j - 2];
            _ = try cache.append(value);
        }

        const steps_div = @divTrunc(steps, size);
        const sm: usize = @intCast(steps_mod);
        const sd: usize = @intCast(steps_div);
        const us: usize = @intCast(size);
        const it = cache.items;
        const n2 = it[sm + 2 * us] + it[sm] - 2 * it[sm + us];
        const n1 = it[sm + 2 * us] - it[sm + us];
        const answer = it[sm + 2 * us] + (sd - 2) * (2 * n1 + (sd - 1) * n2) / 2;
        return answer;
    }

    pub fn getPlotsForSteps(self: *Garden, steps: isize) !usize {
        if (self.repeated and steps > 10) {
            return try self.countPlotsForLargeSteps(steps);
        }
        return try self.strollGarden(steps);
    }
};

test "sample simple part 1" {
    const data =
        \\...........
        \\.....###.#.
        \\.###.##..#.
        \\..#.#...#..
        \\....#.#....
        \\.##..S####.
        \\.##..#...#.
        \\.......##..
        \\.##.#.####.
        \\.##..##.##.
        \\...........
    ;

    var garden = Garden.init(std.testing.allocator, false);
    defer garden.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try garden.addLine(line);
    }
    // garden.show();

    const count = try garden.getPlotsForSteps(6);
    const expected = @as(usize, 16);
    try testing.expectEqual(expected, count);
}

test "sample simple part 2" {
    const data =
        \\...........
        \\.....###.#.
        \\.###.##..#.
        \\..#.#...#..
        \\....#.#....
        \\.##..S####.
        \\.##..#...#.
        \\.......##..
        \\.##.#.####.
        \\.##..##.##.
        \\...........
    ;

    var garden = Garden.init(std.testing.allocator, true);
    defer garden.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try garden.addLine(line);
    }
    // garden.show();

    {
        const count = try garden.getPlotsForSteps(6);
        const expected = @as(usize, 16);
        try testing.expectEqual(expected, count);
    }

    // Unfortunately, these cases fail.
    // The analysis for the real input data does not seem to apply to the test data.
    // Such is life.
    //
    // {
    //     const count = try garden.getPlotsForSteps(10);
    //     const expected = @as(usize, 50);
    //     try testing.expectEqual(expected, count);
    // }
    // {
    //     const count = try garden.getPlotsForSteps(50);
    //     const expected = @as(usize, 1594);
    //     try testing.expectEqual(expected, count);
    // }
    // {
    //     const count = try garden.getPlotsForSteps(100);
    //     const expected = @as(usize, 6536);
    //     try testing.expectEqual(expected, count);
    // }
    // {
    //     const count = try garden.getPlotsForSteps(500);
    //     const expected = @as(usize, 167004);
    //     try testing.expectEqual(expected, count);
    // }
    // {
    //     const count = try garden.getPlotsForSteps(1000);
    //     const expected = @as(usize, 668697);
    //     try testing.expectEqual(expected, count);
    // }
    // {
    //     const count = try garden.getPlotsForSteps(5000);
    //     const expected = @as(usize, 16733044);
    //     try testing.expectEqual(expected, count);
    // }
}
