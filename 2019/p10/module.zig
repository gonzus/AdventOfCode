const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;
const DenseGrid = @import("./util/grid.zig").DenseGrid;

const Allocator = std.mem.Allocator;

pub const Board = struct {
    const Pos = Math.Vector(usize, 2);
    const Grid = DenseGrid(usize);

    const State = struct {
        angle: f64,
        dist: usize,
        pos: Pos,
        shot: bool,

        pub fn init(src: Pos, pos: Pos) State {
            var dx: f64 = 0;
            dx += @floatFromInt(src.v[0]);
            dx -= @floatFromInt(pos.v[0]);

            var dy: f64 = 0;
            dy += @floatFromInt(src.v[1]);
            dy -= @floatFromInt(pos.v[1]);

            // compute theta = atan(dx / dy)
            // in this case we do want the signs for the differences
            // atan returns angles that grow counterclockwise, hence the '-'
            // atan returns negative angles for x<0, hence we add 2*pi then
            var theta = -std.math.atan2(dx, dy);
            if (theta < 0) theta += 2.0 * std.math.pi;

            var dist: usize = 0;
            dist += @intFromFloat(@abs(dx));
            dist += @intFromFloat(@abs(dy));

            return .{
                .angle = theta,
                .dist = dist,
                .pos = pos,
                .shot = false,
            };
        }

        fn cmpByAngleDist(_: void, l: State, r: State) bool {
            if (l.angle < r.angle) return true;
            if (l.angle > r.angle) return false;
            return l.dist < r.dist;
        }
    };

    grid: Grid,
    best_count: usize,
    best_pos: Pos,
    states: std.ArrayList(State),
    seen: std.AutoHashMap(usize, void),

    pub fn init(allocator: Allocator) Board {
        return .{
            .grid = Grid.init(allocator, 0),
            .best_count = 0,
            .best_pos = Pos.init(),
            .states = std.ArrayList(State).init(allocator),
            .seen = std.AutoHashMap(usize, void).init(allocator),
        };
    }

    pub fn deinit(self: *Board) void {
        self.seen.deinit();
        self.states.deinit();
        self.grid.deinit();
    }

    pub fn addLine(self: *Board, str: []const u8) !void {
        try self.grid.ensureCols(str.len);
        try self.grid.ensureExtraRow();
        const y = self.grid.rows();
        for (str, 0..) |c, x| {
            const n: usize = if (c == '#') 1 else 0;
            try self.grid.set(x, y, n);
        }
    }

    pub fn getAsteroidCountFromBestPosition(self: *Board) !usize {
        try self.findBestPosition();
        return self.best_count - 1; // the position itself doesn't count
    }

    pub fn scanAndBlastFromBestPosition(self: *Board, target: usize) !usize {
        try self.findBestPosition();
        return try self.scanAndBlast(self.best_pos, target);
    }

    fn findBestPosition(self: *Board) !void {
        for (0..self.grid.rows()) |srcy| {
            for (0..self.grid.cols()) |srcx| {
                if (self.grid.get(srcx, srcy) == 0) continue;

                // on each turn we "forget" the previous targets
                self.seen.clearRetainingCapacity();
                for (0..self.grid.rows()) |tgty| {
                    for (0..self.grid.cols()) |tgtx| {
                        if (tgtx == srcx and tgty == srcy) continue;
                        if (self.grid.get(tgtx, tgty) == 0) continue;

                        const src = Pos.copy(&[_]usize{ srcx, srcy });
                        const tgt = Pos.copy(&[_]usize{ tgtx, tgty });
                        const label = encodeSrcTgt(src, tgt);
                        const r = try self.seen.getOrPut(label);
                        if (r.found_existing) continue;

                        const next = self.grid.get(srcx, srcy) + 1;
                        try self.grid.set(srcx, srcy, next);
                        if (self.best_count < next) {
                            self.best_count = next;
                            self.best_pos = src;
                        }
                    }
                }
            }
        }
    }

    fn scanAndBlast(self: *Board, src: Pos, sequential: usize) !usize {
        self.states.clearRetainingCapacity();
        for (0..self.grid.rows()) |y| {
            for (0..self.grid.cols()) |x| {
                if (self.grid.get(x, y) == 0) continue;

                const pos = Pos.copy(&[_]usize{ x, y });
                if (src.equal(pos)) continue;

                try self.states.append(State.init(src, pos));
            }
        }

        // sort by angle and distance
        std.sort.heap(State, self.states.items, {}, State.cmpByAngleDist);

        // circle around as many times as necessary to hit the desired sequential target
        var shot: usize = 0;
        while (shot < self.states.items.len) {
            // on each turn we "forget" the previous targets
            self.seen.clearRetainingCapacity();
            for (self.states.items) |*state| {
                // skip positions we have already shot
                if (state.shot) continue;

                const label = encodeSrcTgt(src, state.pos);
                const r = try self.seen.getOrPut(label);
                if (r.found_existing) continue;

                // we have not shot yet in this direction; do it!
                shot += 1;
                state.shot = true;
                if (shot == sequential) {
                    return state.pos.v[0] * 100 + state.pos.v[1];
                }
            }
        }
        return 0;
    }

    fn encodeSrcTgt(src: Pos, tgt: Pos) usize {
        var dir: usize = 0;
        var dx: usize = 0;
        if (src.v[0] > tgt.v[0]) {
            dx = src.v[0] - tgt.v[0];
            dir |= 0x01;
        } else {
            dx = tgt.v[0] - src.v[0];
        }
        var dy: usize = 0;
        if (src.v[1] > tgt.v[1]) {
            dy = src.v[1] - tgt.v[1];
            dir |= 0x10;
        } else {
            dy = tgt.v[1] - src.v[1];
        }
        const gcd = std.math.gcd(dx, dy);
        const canonical = Pos.copy(&[_]usize{ dx / gcd, dy / gcd });
        return (dir * 10 + canonical.v[0]) * 100 + canonical.v[1];
    }
};

test "sample part 1 case A" {
    const data: []const u8 =
        \\.#..#
        \\.....
        \\#####
        \\....#
        \\...##
    ;

    var board = Board.init(testing.allocator);
    defer board.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try board.addLine(line);
    }

    const result = try board.getAsteroidCountFromBestPosition();
    const expected = @as(usize, 8);
    try testing.expectEqual(expected, result);
}

test "sample part 1 case B" {
    const data: []const u8 =
        \\......#.#.
        \\#..#.#....
        \\..#######.
        \\.#.#.###..
        \\.#..#.....
        \\..#....#.#
        \\#..#....#.
        \\.##.#..###
        \\##...#..#.
        \\.#....####
    ;

    var board = Board.init(testing.allocator);
    defer board.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try board.addLine(line);
    }

    const result = try board.getAsteroidCountFromBestPosition();
    const expected = @as(usize, 33);
    try testing.expectEqual(expected, result);
}

test "sample part 1 case C" {
    const data: []const u8 =
        \\#.#...#.#.
        \\.###....#.
        \\.#....#...
        \\##.#.#.#.#
        \\....#.#.#.
        \\.##..###.#
        \\..#...##..
        \\..##....##
        \\......#...
        \\.####.###.
    ;

    var board = Board.init(testing.allocator);
    defer board.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try board.addLine(line);
    }

    const result = try board.getAsteroidCountFromBestPosition();
    const expected = @as(usize, 35);
    try testing.expectEqual(expected, result);
}

test "sample part 1 case D" {
    const data: []const u8 =
        \\.#..#..###
        \\####.###.#
        \\....###.#.
        \\..###.##.#
        \\##.##.#.#.
        \\....###..#
        \\..#.#..#.#
        \\#..#.#.###
        \\.##...##.#
        \\.....#.#..
    ;

    var board = Board.init(testing.allocator);
    defer board.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try board.addLine(line);
    }

    const result = try board.getAsteroidCountFromBestPosition();
    const expected = @as(usize, 41);
    try testing.expectEqual(expected, result);
}

test "sample part 1 case E" {
    const data: []const u8 =
        \\.#..##.###...#######
        \\##.############..##.
        \\.#.######.########.#
        \\.###.#######.####.#.
        \\#####.##.#.##.###.##
        \\..#####..#.#########
        \\####################
        \\#.####....###.#.#.##
        \\##.#################
        \\#####.##.###..####..
        \\..######..##.#######
        \\####.##.####...##..#
        \\.#####..#.######.###
        \\##...#.##########...
        \\#.##########.#######
        \\.####.#.###.###.#.##
        \\....##.##.###..#####
        \\.#.#.###########.###
        \\#.#.#.#####.####.###
        \\###.##.####.##.#..##
    ;

    var board = Board.init(testing.allocator);
    defer board.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try board.addLine(line);
    }

    const result = try board.getAsteroidCountFromBestPosition();
    const expected = @as(usize, 210);
    try testing.expectEqual(expected, result);
}

test "sample part 2 case A" {
    const data: []const u8 =
        \\.#....#####...#..
        \\##...##.#####..##
        \\##...#...#.#####.
        \\..#.....#...###..
        \\..#.#.....#....##
    ;

    var board = Board.init(testing.allocator);
    defer board.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try board.addLine(line);
    }

    const result = try board.scanAndBlast(Board.Pos.copy(&[_]usize{ 8, 3 }), 36);
    const expected = @as(usize, 1403);
    try testing.expectEqual(expected, result);
}

test "sample part 2 case B" {
    const data: []const u8 =
        \\.#..##.###...#######
        \\##.############..##.
        \\.#.######.########.#
        \\.###.#######.####.#.
        \\#####.##.#.##.###.##
        \\..#####..#.#########
        \\####################
        \\#.####....###.#.#.##
        \\##.#################
        \\#####.##.###..####..
        \\..######..##.#######
        \\####.##.####...##..#
        \\.#####..#.######.###
        \\##...#.##########...
        \\#.##########.#######
        \\.####.#.###.###.#.##
        \\....##.##.###..#####
        \\.#.#.###########.###
        \\#.#.#.#####.####.###
        \\###.##.####.##.#..##
    ;

    var board = Board.init(testing.allocator);
    defer board.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try board.addLine(line);
    }

    const result = try board.scanAndBlast(Board.Pos.copy(&[_]usize{ 11, 13 }), 200);
    const expected = @as(usize, 802);
    try testing.expectEqual(expected, result);
}
