const std = @import("std");
const testing = std.testing;
const DEQueue = @import("./util/queue.zig").DoubleEndedQueue;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const MIN_CHEATS = 2;
    const MAX_CHEATS = 20;
    const Dir = enum(u8) {
        U = 'U',
        R = 'R',
        D = 'D',
        L = 'L',

        fn movePos(dir: Dir, x: *isize, y: *isize) void {
            switch (dir) {
                .U => y.* -= 1,
                .R => x.* += 1,
                .D => y.* += 1,
                .L => x.* -= 1,
            }
        }

        pub fn format(
            dir: Dir,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("{c}", .{@intFromEnum(dir)});
        }
    };
    const Dirs = std.meta.tags(Dir);

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            return .{ .x = x, .y = y };
        }

        pub fn equals(self: Pos, other: Pos) bool {
            return self.x == other.x and self.y == other.y;
        }

        pub fn format(
            pos: Pos,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("({}:{})", .{ pos.x, pos.y });
        }
    };

    const Delta = struct {
        x: isize,
        y: isize,

        pub fn init(x: isize, y: isize) Delta {
            return .{ .x = x, .y = y };
        }

        pub fn format(
            delta: Delta,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("({}:{})", .{ delta.x, delta.y });
        }
    };

    const State = struct {
        pos: Pos,
        dist: usize,

        pub fn init(pos: Pos, dist: usize) State {
            return .{ .pos = pos, .dist = dist };
        }

        pub fn format(
            state: State,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("{}={}", .{ state.pos, state.dist });
        }
    };

    const QueueState = DEQueue(State);
    const SetPos = std.AutoHashMap(Pos, void);
    const MapPosDist = std.AutoHashMap(Pos, usize);

    allocator: Allocator,
    cheat_length: usize,
    rows: usize,
    cols: usize,
    start: Pos,
    end: Pos,
    track: SetPos,

    pub fn init(allocator: Allocator, cheat_length: usize) Module {
        return .{
            .allocator = allocator,
            .cheat_length = cheat_length,
            .track = SetPos.init(allocator),
            .rows = 0,
            .cols = 0,
            .start = undefined,
            .end = undefined,
        };
    }

    pub fn deinit(self: *Module) void {
        self.track.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        if (self.cols == 0) {
            self.cols = line.len;
        }
        if (self.cols != line.len) {
            return error.JaggedMap;
        }
        const y = self.rows;
        self.rows += 1;
        for (line, 0..) |c, x| {
            const pos = Pos.init(x, y);
            switch (c) {
                '#' => {},
                '.' => _ = try self.track.getOrPut(pos),
                'S' => {
                    _ = try self.track.getOrPut(pos);
                    self.start = pos;
                },
                'E' => {
                    _ = try self.track.getOrPut(pos);
                    self.end = pos;
                },
                else => return error.InvalidChar,
            }
        }
    }

    // pub fn show(self: Module) void {
    //     std.debug.print("Maze: {}x{}, start {}, end {}, cheat_length: {}\n", .{
    //         self.rows,
    //         self.cols,
    //         self.start,
    //         self.end,
    //         self.cheat_length,
    //     });
    //     for (0..self.rows) |y| {
    //         for (0..self.cols) |x| {
    //             const pos = Pos.init(x, y);
    //             var l: u8 = '#';
    //             if (self.track.contains(pos)) l = '.';
    //             if (self.start.equals(pos)) l = 'S';
    //             if (self.end.equals(pos)) l = 'E';
    //             std.debug.print("{c}", .{l});
    //         }
    //         std.debug.print("\n", .{});
    //     }
    // }

    pub fn getCheatsSavingAtLeast(self: *Module, savings: usize) !usize {
        // self.show();

        var pending = QueueState.init(self.allocator);
        var reachable = SetPos.init(self.allocator);
        var map_pos_dist = MapPosDist.init(self.allocator);
        var list_cheat_dist = std.ArrayList(Delta).init(self.allocator);

        defer pending.deinit();
        defer reachable.deinit();
        defer map_pos_dist.deinit();
        defer list_cheat_dist.deinit();

        try pending.append(State.init(self.start, 0));
        while (!pending.empty()) {
            const state = try pending.pop();
            const r = try reachable.getOrPut(state.pos);
            if (r.found_existing) continue;

            try map_pos_dist.put(state.pos, state.dist);
            if (state.pos.equals(self.end)) break;

            for (Dirs) |dir| {
                var ix: isize = @intCast(state.pos.x);
                var iy: isize = @intCast(state.pos.y);
                dir.movePos(&ix, &iy);
                if (ix < 0 or ix >= self.cols - 1) continue;
                if (iy < 0 or iy >= self.rows - 1) continue;
                const pos = Pos.init(@intCast(ix), @intCast(iy));
                if (reachable.contains(pos)) continue;
                if (!self.track.contains(pos)) continue;
                try pending.append(State.init(pos, state.dist + 1));
            }
        }

        // manually insert distances within two cheats
        // because I cannot be arsed to make this depend on MIN_CHEATS
        try list_cheat_dist.append(Delta.init(2, 0));
        try list_cheat_dist.append(Delta.init(-2, 0));
        try list_cheat_dist.append(Delta.init(0, 2));
        try list_cheat_dist.append(Delta.init(0, -2));
        try list_cheat_dist.append(Delta.init(1, 1));
        try list_cheat_dist.append(Delta.init(-1, 1));
        try list_cheat_dist.append(Delta.init(1, -1));
        try list_cheat_dist.append(Delta.init(-1, -1));

        // insert distances withing MAX_CHEATS
        var dx: isize = -MAX_CHEATS;
        while (dx <= MAX_CHEATS) : (dx += 1) {
            var dy: isize = -MAX_CHEATS;
            while (dy <= MAX_CHEATS) : (dy += 1) {
                const mahattan_distance = @abs(dx) + @abs(dy);
                if (mahattan_distance > MAX_CHEATS or mahattan_distance <= MIN_CHEATS) continue;
                try list_cheat_dist.append(Delta.init(dx, dy));
            }
        }

        var count: usize = 0;
        var it = reachable.keyIterator();
        while (it.next()) |location| {
            const home_score = map_pos_dist.get(location.*).?;
            for (list_cheat_dist.items) |cheat_dist| {
                var ix: isize = @intCast(location.*.x);
                var iy: isize = @intCast(location.*.y);
                ix += cheat_dist.x;
                iy += cheat_dist.y;
                if (ix < 0 or ix >= self.cols - 1) continue;
                if (iy < 0 or iy >= self.rows - 1) continue;

                const pos = Pos.init(@intCast(ix), @intCast(iy));
                if (!reachable.contains(pos)) continue;

                const reached_score = map_pos_dist.get(pos).?;
                const cheat_length = @abs(cheat_dist.x) + @abs(cheat_dist.y);
                if (reached_score < home_score + savings + cheat_length) continue;
                if (cheat_length > self.cheat_length) continue;

                count += 1;
            }
        }

        return count;
    }
};

test "sample part 1 example 1" {
    const data =
        \\###############
        \\#...#...#.....#
        \\#.#.#.#.#.###.#
        \\#S#...#.#.#...#
        \\#######.#.#.###
        \\#######.#.#...#
        \\#######.#.###.#
        \\###..E#...#...#
        \\###.#######.###
        \\#...###...#...#
        \\#.#####.#.###.#
        \\#.#...#.#.#...#
        \\#.#.#.#.#.#.###
        \\#...#...#...###
        \\###############
    ;

    var module = Module.init(testing.allocator, 2);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getCheatsSavingAtLeast(5);
    const expected = @as(usize, 16);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\###############
        \\#...#...#.....#
        \\#.#.#.#.#.###.#
        \\#S#...#.#.#...#
        \\#######.#.#.###
        \\#######.#.#...#
        \\#######.#.###.#
        \\###..E#...#...#
        \\###.#######.###
        \\#...###...#...#
        \\#.#####.#.###.#
        \\#.#...#.#.#...#
        \\#.#.#.#.#.#.###
        \\#...#...#...###
        \\###############
    ;

    var module = Module.init(testing.allocator, 20);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getCheatsSavingAtLeast(70);
    const expected = @as(usize, 41);
    try testing.expectEqual(expected, count);
}
