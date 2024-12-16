const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const SIZE = 150;
    const INFINITY = std.math.maxInt(usize);
    const MOVE_COST = 1;
    const ROTATE_COST = 1000;

    const Dir = enum(u8) {
        N = 'N',
        E = 'E',
        S = 'S',
        W = 'W',

        fn movePos(dir: Dir, x: *isize, y: *isize) void {
            switch (dir) {
                .N => y.* -= 1,
                .E => x.* += 1,
                .S => y.* += 1,
                .W => x.* -= 1,
            }
        }

        fn rotateClockwise(self: *Dir) void {
            self.* = switch (self.*) {
                .N => .E,
                .E => .S,
                .S => .W,
                .W => .N,
            };
        }

        fn rotateCounterClockwise(self: *Dir) void {
            self.* = switch (self.*) {
                .N => .W,
                .E => .N,
                .S => .E,
                .W => .S,
            };
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

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            return .{ .x = x, .y = y };
        }

        pub fn equals(self: Pos, other: Pos) bool {
            return self.x == other.x and self.y == other.y;
        }

        fn manhattanDistance(self: Pos, other: Pos) usize {
            var dist: usize = 0;
            dist += if (self.x > other.x) self.x - other.x else other.x - self.x;
            dist += if (self.y > other.y) self.y - other.y else other.y - self.y;
            return dist;
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

    const State = struct {
        pos: Pos,
        dir: Dir,

        pub fn init(pos: Pos, dir: Dir) State {
            return .{ .pos = pos, .dir = dir };
        }

        pub fn format(
            state: State,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("{}@{}", .{ state.pos, state.dir });
        }
    };

    allocator: Allocator,
    grid: [SIZE][SIZE]u8,
    rows: usize,
    cols: usize,
    start: Pos,
    end: Pos,
    dir: Dir,
    best_cost: usize,
    best_route: std.AutoHashMap(Pos, void),
    current_path: std.AutoHashMap(State, void),
    cheapest: std.AutoHashMap(State, usize),

    pub fn init(allocator: Allocator) Module {
        return .{
            .allocator = allocator,
            .grid = undefined,
            .rows = 0,
            .cols = 0,
            .start = undefined,
            .end = undefined,
            .dir = .E,
            .best_cost = INFINITY,
            .best_route = std.AutoHashMap(Pos, void).init(allocator),
            .current_path = std.AutoHashMap(State, void).init(allocator),
            .cheapest = std.AutoHashMap(State, usize).init(allocator),
        };
    }

    pub fn deinit(self: *Module) void {
        self.cheapest.deinit();
        self.current_path.deinit();
        self.best_route.deinit();
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
            switch (c) {
                '#', '.' => self.grid[x][y] = c,
                'S' => {
                    self.start = Pos.init(x, y);
                    self.grid[x][y] = '.';
                },
                'E' => {
                    self.end = Pos.init(x, y);
                    self.grid[x][y] = '.';
                },
                else => return error.InvalidChar,
            }
        }
    }

    // pub fn show(self: Module) void {
    //     std.debug.print("Maze: {}x{}, start {}, end {}\n", .{
    //         self.rows,
    //         self.cols,
    //         self.start,
    //         self.end,
    //     });
    //     for (0..self.rows) |y| {
    //         for (0..self.cols) |x| {
    //             var l = self.grid[x][y];
    //             if (l == '.' and x == self.start.x and y == self.start.y) {
    //                 l = 'S';
    //             }
    //             if (l == '.' and x == self.end.x and y == self.end.y) {
    //                 l = 'E';
    //             }
    //             std.debug.print("{c}", .{l});
    //         }
    //         std.debug.print("\n", .{});
    //     }
    // }

    pub fn getLowestScore(self: *Module) !usize {
        // self.show();

        var search = AStar.init(self.allocator, self);
        defer search.deinit();
        _ = try search.run(self.start, self.end);
        return self.best_cost;
    }

    pub fn countBestTiles(self: *Module) !usize {
        // self.show();

        var search = AStar.init(self.allocator, self);
        defer search.deinit();
        var state = try search.run(self.start, self.end);

        // seed the cheapest values for the optimal path
        while (true) {
            var cost: usize = 0;
            if (search.gScore.get(state)) |s| {
                cost = s;
            }
            _ = try self.cheapest.getOrPutValue(state, cost);
            if (search.cameFrom.get(state)) |parent| {
                state = parent;
            } else break;
        }

        // walk around and look for any routes with the optimal cost
        try self.walkMap(State.init(self.start, .E), 0, 0);

        // // mark all positions that are path of an optimal path
        // var it = self.best_route.keyIterator();
        // while (it.next()) |pos| {
        //     self.grid[pos.*.x][pos.*.y] = 'O';
        // }
        // self.show();

        return self.best_route.count();
    }

    fn walkMap(self: *Module, state: State, cost: usize, depth: usize) !void {
        if (cost > self.best_cost) {
            // even if we are at a solution, we have a ceiling for the cost
            return;
        }
        const r = try self.cheapest.getOrPut(state);
        if (r.found_existing) {
            if (cost > r.value_ptr.*) {
                // if there are cheaper ways to get here, abort
                return;
            }
        }
        r.value_ptr.* = cost;
        try self.current_path.put(state, {});
        defer _ = self.current_path.remove(state);

        if (state.pos.equals(self.end)) {
            // found a solution at optimal cost
            // store the path to the solution
            var it = self.current_path.keyIterator();
            while (it.next()) |k| {
                _ = try self.best_route.getOrPut(k.*.pos);
            }
            return;
        }

        {
            // Try walking in the direction we are headed
            var ix: isize = @intCast(state.pos.x);
            var iy: isize = @intCast(state.pos.y);
            state.dir.movePos(&ix, &iy);
            const nx: usize = @intCast(ix);
            const ny: usize = @intCast(iy);
            if (self.grid[nx][ny] == '.') {
                const npos = Pos.init(nx, ny);
                try self.walkMap(State.init(npos, state.dir), cost + MOVE_COST, depth + 1);
            }
        }
        {
            // Try rotating clockwise
            var ndir = state.dir;
            ndir.rotateClockwise();
            try self.walkMap(State.init(state.pos, ndir), cost + ROTATE_COST, depth + 1);
        }
        {
            // Try rotating counter-clockwise
            var ndir = state.dir;
            ndir.rotateCounterClockwise();
            try self.walkMap(State.init(state.pos, ndir), cost + ROTATE_COST, depth + 1);
        }
    }

    const AStar = struct {
        const StateDist = struct {
            state: State,
            dist: usize,

            pub fn init(state: State, dist: usize) StateDist {
                return StateDist{ .state = state, .dist = dist };
            }

            fn lessThan(_: void, l: StateDist, r: StateDist) std.math.Order {
                return std.math.order(l.dist, r.dist);
            }
        };

        module: *Module,
        // because openSet is a priority queue, it contains both the pending nodes to visit and the value of fScore
        openSet: std.PriorityQueue(StateDist, void, StateDist.lessThan),
        gScore: std.AutoHashMap(State, usize), // lowest distance so far to each node
        cameFrom: std.AutoHashMap(State, State), // trace path to target

        pub fn init(allocator: Allocator, module: *Module) AStar {
            return AStar{
                .module = module,
                .openSet = std.PriorityQueue(StateDist, void, StateDist.lessThan).init(allocator, {}),
                .gScore = std.AutoHashMap(State, usize).init(allocator),
                .cameFrom = std.AutoHashMap(State, State).init(allocator),
            };
        }

        pub fn deinit(self: *AStar) void {
            self.cameFrom.deinit();
            self.gScore.deinit();
            self.openSet.deinit();
        }

        pub fn run(self: *AStar, src: Pos, tgt: Pos) !State {
            const src_state = State.init(src, self.module.dir);
            try self.gScore.put(src_state, 0);
            try self.openSet.add(StateDist.init(src_state, src.manhattanDistance(tgt)));
            while (self.openSet.count() != 0) {
                const sd = self.openSet.remove();
                const ustate = sd.state;
                if (ustate.pos.equals(tgt)) {
                    // Found target
                    if (self.module.best_cost > sd.dist) {
                        self.module.best_cost = sd.dist;
                    }
                    return ustate;
                }

                {
                    // Try walking in the direction we are headed
                    var ix: isize = @intCast(ustate.pos.x);
                    var iy: isize = @intCast(ustate.pos.y);
                    ustate.dir.movePos(&ix, &iy);
                    const nx: usize = @intCast(ix);
                    const ny: usize = @intCast(iy);
                    if (self.module.grid[nx][ny] == '.') {
                        const npos = Pos.init(nx, ny);
                        try self.checkAndAddNeighbor(ustate, State.init(npos, ustate.dir), MOVE_COST);
                    }
                }
                {
                    // Try rotating clockwise
                    var ndir = ustate.dir;
                    ndir.rotateClockwise();
                    try self.checkAndAddNeighbor(ustate, State.init(ustate.pos, ndir), ROTATE_COST);
                }
                {
                    // Try rotating counter-clockwise
                    var ndir = ustate.dir;
                    ndir.rotateCounterClockwise();
                    try self.checkAndAddNeighbor(ustate, State.init(ustate.pos, ndir), ROTATE_COST);
                }
            }
            return src_state;
        }

        fn checkAndAddNeighbor(self: *AStar, u: State, v: State, cost: usize) !void {
            var du: usize = INFINITY;
            if (self.gScore.get(u)) |d| {
                du = d;
            }
            var dv: usize = INFINITY;
            if (self.gScore.get(v)) |d| {
                dv = d;
            }
            const tentative = du + cost;
            if (tentative >= dv) return;

            const estimate = v.pos.manhattanDistance(self.module.end);
            try self.cameFrom.put(v, u);
            try self.gScore.put(v, tentative);
            try self.openSet.add(StateDist.init(v, tentative + estimate));
        }
    };
};

test "sample part 1 example 1" {
    const data =
        \\###############
        \\#.......#....E#
        \\#.#.###.#.###.#
        \\#.....#.#...#.#
        \\#.###.#####.#.#
        \\#.#.#.......#.#
        \\#.#.#####.###.#
        \\#...........#.#
        \\###.#.#####.#.#
        \\#...#.....#.#.#
        \\#.#.#.###.#.#.#
        \\#.....#...#.#.#
        \\#.###.#.#.#.#.#
        \\#S..#.....#...#
        \\###############
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getLowestScore();
    const expected = @as(usize, 7036);
    try testing.expectEqual(expected, count);
}

test "sample part 1 example 2" {
    const data =
        \\#################
        \\#...#...#...#..E#
        \\#.#.#.#.#.#.#.#.#
        \\#.#.#.#...#...#.#
        \\#.#.#.#.###.#.#.#
        \\#...#.#.#.....#.#
        \\#.#.#.#.#.#####.#
        \\#.#...#.#.#.....#
        \\#.#.#####.#.###.#
        \\#.#.#.......#...#
        \\#.#.###.#####.###
        \\#.#.#...#.....#.#
        \\#.#.#.#####.###.#
        \\#.#.#.........#.#
        \\#.#.#.#########.#
        \\#S#.............#
        \\#################
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getLowestScore();
    const expected = @as(usize, 11048);
    try testing.expectEqual(expected, count);
}

test "sample part 2 example 1" {
    const data =
        \\###############
        \\#.......#....E#
        \\#.#.###.#.###.#
        \\#.....#.#...#.#
        \\#.###.#####.#.#
        \\#.#.#.......#.#
        \\#.#.#####.###.#
        \\#...........#.#
        \\###.#.#####.#.#
        \\#...#.....#.#.#
        \\#.#.#.###.#.#.#
        \\#.....#...#.#.#
        \\#.###.#.#.#.#.#
        \\#S..#.....#...#
        \\###############
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.countBestTiles();
    const expected = @as(usize, 45);
    try testing.expectEqual(expected, count);
}

test "sample part 2 example 2" {
    const data =
        \\#################
        \\#...#...#...#..E#
        \\#.#.#.#.#.#.#.#.#
        \\#.#.#.#...#...#.#
        \\#.#.#.#.###.#.#.#
        \\#...#.#.#.....#.#
        \\#.#.#.#.#.#####.#
        \\#.#...#.#.#.....#
        \\#.#.#####.#.###.#
        \\#.#.#.......#...#
        \\#.#.###.#####.###
        \\#.#.#...#.....#.#
        \\#.#.#.#####.###.#
        \\#.#.#.........#.#
        \\#.#.#.#########.#
        \\#S#.............#
        \\#################
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.countBestTiles();
    const expected = @as(usize, 64);
    try testing.expectEqual(expected, count);
}
