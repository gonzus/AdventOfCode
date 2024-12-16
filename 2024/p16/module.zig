const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const SIZE = 200;
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

        pub fn encode(self: Pos) usize {
            return self.x * 1000 + self.y;
        }

        pub fn decode(code: usize) Pos {
            var p = code;
            const y = p % 1000;
            p /= 1000;
            const x = p % 1000;
            p /= 1000;
            return Pos.init(x, y);
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

        pub fn init(pos: Pos, dir: Dir) !State {
            const self = State{
                .pos = pos,
                .dir = dir,
            };
            return self;
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
        };
    }

    pub fn deinit(self: *Module) void {
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

        var search = AStar.init(self);
        defer search.deinit();
        _ = try search.run(self.start, self.end, false);
        return self.best_cost;
    }

    pub fn countBestTiles(self: *Module) !usize {
        // self.show();

        var search = AStar.init(self);
        defer search.deinit();
        _ = try search.run(self.start, self.end, true);

        // var it = self.best_route.keyIterator();
        // while (it.next()) |pos| {
        //     self.grid[pos.x][pos.y] = 'O';
        // }
        // self.show();

        return self.best_route.count();
    }

    const AStar = struct {
        const StateDist = struct {
            state: State,
            dist: usize,
            pbuf: [10 * 1024]usize,
            plen: usize,

            pub fn init(state: State, dist: usize) StateDist {
                var self = StateDist{
                    .state = state,
                    .dist = dist,
                    .pbuf = undefined,
                    .plen = 0,
                };
                self.append(state.pos);
                return self;
            }

            pub fn format(
                sd: StateDist,
                comptime _: []const u8,
                _: std.fmt.FormatOptions,
                writer: anytype,
            ) !void {
                _ = try writer.print("{}={}", .{ sd.state, sd.dist });
            }

            pub fn append(self: *StateDist, pos: Pos) void {
                self.pbuf[self.plen] = pos.encode();
                self.plen += 1;
            }

            pub fn copyParents(self: *StateDist, parent: StateDist) void {
                std.mem.copyForwards(usize, self.pbuf[self.plen..], parent.pbuf[0..parent.plen]);
                self.plen += parent.plen;
            }

            fn lessThan(_: void, l: StateDist, r: StateDist) std.math.Order {
                return std.math.order(l.dist, r.dist);
            }
        };

        module: *Module,
        // because openSet is a priority queue, it contains both the pending nodes to visit and the value of fScore
        openSet: std.PriorityQueue(StateDist, void, StateDist.lessThan),
        gScore: std.AutoHashMap(State, usize), // lowest distance so far to each node

        pub fn init(module: *Module) AStar {
            return AStar{
                .module = module,
                .openSet = std.PriorityQueue(StateDist, void, StateDist.lessThan).init(module.allocator, {}),
                .gScore = std.AutoHashMap(State, usize).init(module.allocator),
            };
        }

        pub fn deinit(self: *AStar) void {
            self.gScore.deinit();
            self.openSet.deinit();
        }

        pub fn run(self: *AStar, src: Pos, tgt: Pos, all: bool) !void {
            const src_state = try State.init(src, self.module.dir);
            try self.gScore.put(src_state, 0);
            try self.openSet.add(StateDist.init(src_state, 0));
            while (self.openSet.count() != 0) {
                const usd = self.openSet.remove();
                const u = usd.state;
                if (u.pos.equals(tgt)) {
                    // Found target
                    if (self.module.best_cost == INFINITY) {
                        self.module.best_cost = usd.dist;
                        if (!all) break;
                    }
                    if (self.module.best_cost < usd.dist) break;
                    for (0..usd.plen) |n| {
                        const pos = Pos.decode(usd.pbuf[n]);
                        _ = try self.module.best_route.getOrPut(pos);
                    }
                }

                var du: usize = INFINITY;
                if (self.gScore.get(u)) |d| {
                    du = d;
                }

                for (Dirs) |ndir| {
                    var ix: isize = @intCast(u.pos.x);
                    var iy: isize = @intCast(u.pos.y);
                    ndir.movePos(&ix, &iy);
                    if (ix < 0 or ix >= self.module.cols) continue;
                    if (iy < 0 or iy >= self.module.rows) continue;

                    const nx: usize = @intCast(ix);
                    const ny: usize = @intCast(iy);
                    if (self.module.grid[nx][ny] == '#') continue;

                    const npos = Pos.init(nx, ny);
                    var cost: usize = MOVE_COST;
                    if (u.dir != ndir) cost += ROTATE_COST;

                    const v = try State.init(npos, ndir);
                    var dv: usize = INFINITY;
                    if (self.gScore.get(v)) |d| {
                        dv = d;
                    }

                    const tentative = du + cost;
                    if (tentative > dv) continue;
                    if (!all and tentative == dv) continue;

                    try self.gScore.put(v, tentative);
                    var vsd = StateDist.init(v, usd.dist + cost);
                    vsd.copyParents(usd);
                    try self.openSet.add(vsd);
                }
            }
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

test "sample part 1 example reddit" {
    const data =
        \\###########################
        \\#######################..E#
        \\######################..#.#
        \\#####################..##.#
        \\####################..###.#
        \\###################..##...#
        \\##################..###.###
        \\#################..####...#
        \\################..#######.#
        \\###############..##.......#
        \\##############..###.#######
        \\#############..####.......#
        \\############..###########.#
        \\###########..##...........#
        \\##########..###.###########
        \\#########..####...........#
        \\########..###############.#
        \\#######..##...............#
        \\######..###.###############
        \\#####..####...............#
        \\####..###################.#
        \\###..##...................#
        \\##..###.###################
        \\#..####...................#
        \\#.#######################.#
        \\#S........................#
        \\###########################
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getLowestScore();
    const expected = @as(usize, 21148);
    try testing.expectEqual(expected, count);
}

test "sample part 2 gonzo" {
    const data =
        \\######
        \\#...E#
        \\#S.#.#
        \\######
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.countBestTiles();
    const expected = @as(usize, 6);
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

test "sample part 2 example reddit" {
    const data =
        \\###########################
        \\#######################..E#
        \\######################..#.#
        \\#####################..##.#
        \\####################..###.#
        \\###################..##...#
        \\##################..###.###
        \\#################..####...#
        \\################..#######.#
        \\###############..##.......#
        \\##############..###.#######
        \\#############..####.......#
        \\############..###########.#
        \\###########..##...........#
        \\##########..###.###########
        \\#########..####...........#
        \\########..###############.#
        \\#######..##...............#
        \\######..###.###############
        \\#####..####...............#
        \\####..###################.#
        \\###..##...................#
        \\##..###.###################
        \\#..####...................#
        \\#.#######################.#
        \\#S........................#
        \\###########################
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.countBestTiles();
    const expected = @as(usize, 149);
    try testing.expectEqual(expected, count);
}
