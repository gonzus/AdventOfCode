const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Platform = struct {
    const CYCLES = 1000000000;

    const Dir = enum {
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

        pub fn init(dir: Dir) Delta {
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

        pub fn init(dir: Dir, size: Pos) Tilt {
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

    const Cycle = struct {
        const SIZE = std.meta.tags(Dir).len;

        loads: [SIZE]usize,

        pub fn init() Cycle {
            var self = Cycle{
                .loads = [_]usize{0} ** SIZE,
            };
            return self;
        }

        pub fn setDirLoad(self: *Cycle, dir: Dir, load: usize) void {
            self.loads[@intFromEnum(dir)] = load;
        }
    };

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            var self = Pos{ .x = x, .y = y };
            return self;
        }

        pub fn initFromSigned(x: isize, y: isize) Pos {
            return Pos.init(@intCast(x), @intCast(y));
        }
    };

    const Grid = std.AutoHashMap(Pos, Piece);

    allocator: Allocator,
    cycle: bool,
    size: Pos,
    data: Grid,

    pub fn init(allocator: Allocator, cycle: bool) Platform {
        var self = Platform{
            .allocator = allocator,
            .cycle = cycle,
            .size = Pos.init(0, 0),
            .data = Grid.init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Platform) void {
        self.data.deinit();
    }

    pub fn addLine(self: *Platform, line: []const u8) !void {
        if (self.size.x < line.len) {
            self.size.x = line.len;
        }
        for (line, 0..) |c, x| {
            const pos = Pos.init(x, self.size.y);
            const piece = Piece.parse(c);
            _ = try self.data.getOrPutValue(pos, piece);
        }
        self.size.y += 1;
    }

    pub fn show(self: *Platform) void {
        std.debug.print("Platform: {} x {}\n", .{ self.size.y, self.size.x });
        for (0..self.size.y) |y| {
            for (0..self.size.x) |x| {
                const pos = Pos.init(x, y);
                const piece = self.data.get(pos) orelse .Empty;
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

        var cycles = std.ArrayList(Cycle).init(self.allocator);
        defer cycles.deinit();
        var seen = std.AutoHashMap(Cycle, usize).init(self.allocator);
        defer seen.deinit();

        var first_repeat: usize = 0;
        var value_repeated: usize = 0;
        var cycle_length: usize = 0;
        var step: usize = 0;
        while (cycle_length == 0) : (step += 1) {
            const cycle = try self.runCycle();
            const entry = try seen.getOrPut(cycle);
            if (entry.found_existing) {
                if (first_repeat == 0) {
                    first_repeat = step;
                    value_repeated = entry.value_ptr.*;
                } else if (cycle_length == 0 and value_repeated == entry.value_ptr.*) {
                    cycle_length = step - first_repeat;
                }
            } else {
                entry.value_ptr.* = step;
                try cycles.append(cycle);
            }
        }
        // step is zero-based, must decrease CYCLES by 1
        const pos = (CYCLES - 1 - first_repeat) % cycle_length + first_repeat - cycle_length;
        const wanted = cycles.items[pos];
        return wanted.loads[3];
    }

    fn getLoad(self: *Platform) usize {
        var sum: usize = 0;
        for (0..self.size.y) |y| {
            var count: usize = 0;
            for (0..self.size.x) |x| {
                const pos = Pos.init(x, y);
                const piece = self.data.get(pos) orelse .Empty;
                if (piece != .Round) continue;
                count += 1;
            }
            sum += count * (self.size.y - y);
        }
        return sum;
    }

    fn runTilt(self: *Platform, dir: Dir) !void {
        const tilt = Tilt.init(dir, self.size);
        var row = tilt.row.start;
        while (true) : (row += tilt.row.delta) {
            var col = tilt.col.start;
            while (true) : (col += tilt.col.delta) {
                const src_pos = Pos.initFromSigned(col, row);
                var src_entry = self.data.getEntry(src_pos);
                const src_piece = src_entry.?.value_ptr.*;
                if (src_piece != .Round) {
                    if (tilt.col.done(col)) break;
                    continue;
                }
                var tgt_entry: ?Grid.Entry = null;
                var step: isize = 1;
                while (true) : (step += 1) {
                    var nx = col + tilt.delta.x * step;
                    if (nx < 0 or nx > self.size.x - 1) break;
                    var ny = row + tilt.delta.y * step;
                    if (ny < 0 or ny > self.size.y - 1) break;
                    const new_pos = Pos.initFromSigned(nx, ny);
                    const new_entry = self.data.getEntry(new_pos);
                    const new_piece = new_entry.?.value_ptr.*;
                    if (new_piece != .Empty) break;
                    tgt_entry = new_entry;
                }
                if (tgt_entry == null) {
                    if (tilt.col.done(col)) break;
                    continue;
                }
                src_entry.?.value_ptr.* = .Empty;
                tgt_entry.?.value_ptr.* = .Round;
                if (tilt.col.done(col)) break;
            }
            if (tilt.row.done(row)) break;
        }
    }

    fn runCycle(self: *Platform) !Cycle {
        var cycle = Cycle.init();
        for (std.meta.tags(Dir)) |dir| {
            try self.runTilt(dir);
            const load = self.getLoad();
            cycle.setDirLoad(dir, load);
        }
        return cycle;
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
