const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Platform = struct {
    const NUM_CYCLES = 1000000000;

    const Direction = enum {
        N,
        W,
        S,
        E,
    };

    const Slope = enum {
        Ascending,
        Descending,
    };

    const Piece = enum(u8) {
        Round = 'O',
        Cube = '#',
        Empty = '.',

        pub fn parse(c: u8) Piece {
            const piece: Piece = switch (c) {
                'O' => .Round,
                '#' => .Cube,
                '.' => .Empty,
                else => unreachable,
            };
            return piece;
        }
    };

    const Iteration = struct {
        start: isize,
        end: isize,
        delta: isize,

        pub fn init(slope: Slope, size: usize) Iteration {
            var self = Iteration{ .start = 0, .end = 0, .delta = 0 };
            switch (slope) {
                .Descending => {
                    self.end = @intCast(size - 1);
                    self.delta = 1;
                },
                .Ascending => {
                    self.start = @intCast(size - 1);
                    self.delta = -1;
                },
            }
            return self;
        }

        pub fn done(self: Iteration, value: isize) bool {
            return value == self.end;
        }
    };

    const Delta = struct {
        x: isize,
        y: isize,

        pub fn init(dir: Direction) Delta {
            var self = Delta{ .x = 0, .y = 0 };
            switch (dir) {
                .N => self.y = -1,
                .S => self.y = 1,
                .E => self.x = 1,
                .W => self.x = -1,
            }
            return self;
        }
    };

    const Tilt = struct {
        row: Iteration,
        col: Iteration,
        delta: Delta,

        pub fn init(dir: Direction, size: Pair) Tilt {
            var self = Tilt{
                .row = switch (dir) {
                    .N => Iteration.init(.Descending, size.y),
                    else => Iteration.init(.Ascending, size.y),
                },
                .col = switch (dir) {
                    .W => Iteration.init(.Descending, size.x),
                    else => Iteration.init(.Ascending, size.x),
                },
                .delta = Delta.init(dir),
            };
            return self;
        }
    };

    const State = struct {
        const DIR_SIZE = std.meta.tags(Direction).len;

        loads: [DIR_SIZE]usize,

        pub fn init() State {
            var self = State{
                .loads = [_]usize{0} ** DIR_SIZE,
            };
            return self;
        }

        pub fn setDirectionLoad(self: *State, dir: Direction, load: usize) void {
            self.loads[@intFromEnum(dir)] = load;
        }
    };

    const Pair = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pair {
            var self = Pair{ .x = x, .y = y };
            return self;
        }

        pub fn initFromSigned(x: isize, y: isize) Pair {
            return Pair.init(@intCast(x), @intCast(y));
        }
    };

    const GRID_MAX_SIZE = 120;

    allocator: Allocator,
    cycle: bool,
    size: Pair,
    data: [GRID_MAX_SIZE][GRID_MAX_SIZE]Piece,

    pub fn init(allocator: Allocator, cycle: bool) Platform {
        var self = Platform{
            .allocator = allocator,
            .cycle = cycle,
            .size = Pair.init(0, 0),
            .data = undefined,
        };
        return self;
    }

    pub fn deinit(self: *Platform) void {
        _ = self;
    }

    pub fn addLine(self: *Platform, line: []const u8) !void {
        if (self.size.x < line.len) {
            self.size.x = line.len;
        }
        for (line, 0..) |c, x| {
            const piece = Piece.parse(c);
            self.data[x][self.size.y] = piece;
        }
        self.size.y += 1;
    }

    pub fn show(self: *Platform) void {
        std.debug.print("Platform: {} x {}\n", .{ self.size.y, self.size.x });
        for (0..self.size.y) |y| {
            for (0..self.size.x) |x| {
                const piece = self.data[x][y];
                std.debug.print("{c}", .{@intFromEnum(piece)});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn getTotalLoad(self: *Platform) !usize {
        if (!self.cycle) {
            try self.runTilt(.N);
            return self.getLoad();
        }

        var states = std.ArrayList(State).init(self.allocator);
        defer states.deinit();
        var seen = std.AutoHashMap(State, usize).init(self.allocator);
        defer seen.deinit();

        var first_repeat: usize = 0;
        var value_repeated: usize = 0;
        var cycle_length: usize = 0;
        var step: usize = 0;
        while (cycle_length == 0) : (step += 1) {
            const state = try self.runCycle();
            const entry = try seen.getOrPut(state);
            if (entry.found_existing) {
                if (first_repeat == 0) {
                    first_repeat = step;
                    value_repeated = entry.value_ptr.*;
                } else if (cycle_length == 0 and value_repeated == entry.value_ptr.*) {
                    cycle_length = step - first_repeat;
                }
            } else {
                entry.value_ptr.* = step;
                try states.append(state);
            }
        }
        // step is zero-based, must decrease NUM_CYCLES by 1
        const pos = (NUM_CYCLES - 1 - first_repeat) % cycle_length + first_repeat - cycle_length;
        const wanted = states.items[pos];
        return wanted.loads[3];
    }

    fn getLoad(self: *Platform) usize {
        var sum: usize = 0;
        for (0..self.size.y) |y| {
            var count: usize = 0;
            for (0..self.size.x) |x| {
                const piece = self.data[x][y];
                if (piece != .Round) continue;
                count += 1;
            }
            sum += count * (self.size.y - y);
        }
        return sum;
    }

    fn runTilt(self: *Platform, dir: Direction) !void {
        const tilt = Tilt.init(dir, self.size);
        var row = tilt.row.start;
        while (true) : (row += tilt.row.delta) {
            var col = tilt.col.start;
            while (true) : (col += tilt.col.delta) {
                const src_pos = Pair.initFromSigned(col, row);
                const src_piece = self.data[src_pos.x][src_pos.y];
                if (src_piece != .Round) {
                    if (tilt.col.done(col)) break;
                    continue;
                }
                var tgt_pos_opt: ?Pair = null;
                var step: isize = 1;
                while (true) : (step += 1) {
                    var nx = col + tilt.delta.x * step;
                    if (nx < 0 or nx > self.size.x - 1) break;
                    var ny = row + tilt.delta.y * step;
                    if (ny < 0 or ny > self.size.y - 1) break;
                    const new_pos = Pair.initFromSigned(nx, ny);
                    const new_piece = self.data[new_pos.x][new_pos.y];
                    if (new_piece != .Empty) break;
                    tgt_pos_opt = new_pos;
                }
                if (tgt_pos_opt) |tgt_pos| {
                    self.data[src_pos.x][src_pos.y] = .Empty;
                    self.data[tgt_pos.x][tgt_pos.y] = .Round;
                }
                if (tilt.col.done(col)) break;
            }
            if (tilt.row.done(row)) break;
        }
    }

    fn runCycle(self: *Platform) !State {
        var state = State.init();
        for (std.meta.tags(Direction)) |dir| {
            try self.runTilt(dir);
            const load = self.getLoad();
            state.setDirectionLoad(dir, load);
        }
        return state;
    }
};

test "sample part 1" {
    const data =
        \\O....#....
        \\O.OO#....#
        \\.....##...
        \\OO.#O....O
        \\.O.....O#.
        \\O.#..O.#.#
        \\..O..#O..O
        \\.......O..
        \\#....###..
        \\#OO..#....
    ;

    var platform = Platform.init(std.testing.allocator, false);
    defer platform.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try platform.addLine(line);
    }

    const summary = try platform.getTotalLoad();
    const expected = @as(usize, 136);
    try testing.expectEqual(expected, summary);
}

test "sample part 2" {
    const data =
        \\O....#....
        \\O.OO#....#
        \\.....##...
        \\OO.#O....O
        \\.O.....O#.
        \\O.#..O.#.#
        \\..O..#O..O
        \\.......O..
        \\#....###..
        \\#OO..#....
    ;

    var platform = Platform.init(std.testing.allocator, true);
    defer platform.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try platform.addLine(line);
    }

    const summary = try platform.getTotalLoad();
    const expected = @as(usize, 64);
    try testing.expectEqual(expected, summary);
}
