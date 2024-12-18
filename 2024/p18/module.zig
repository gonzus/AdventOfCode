const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const SIZE = 80;
    const MAX_TEST = 6;
    const MAX_DAY = 70;
    const INFINITY = std.math.maxInt(usize);

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

    const AStar = struct {
        const State = Pos;
        const PQ = std.PriorityQueue(StateDist, void, StateDist.lessThan);

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

        // because openSet is a priority queue, it contains both the pending nodes to visit and the value of fScore
        openSet: PQ,
        gScore: std.AutoHashMap(State, usize), // lowest distance so far to each node
        cameFrom: std.AutoHashMap(State, State), // trace path to target

        pub fn init(allocator: Allocator) AStar {
            return AStar{
                .openSet = PQ.init(allocator, {}),
                .gScore = std.AutoHashMap(State, usize).init(allocator),
                .cameFrom = std.AutoHashMap(State, State).init(allocator),
            };
        }

        pub fn deinit(self: *AStar) void {
            self.cameFrom.deinit();
            self.gScore.deinit();
            self.openSet.deinit();
        }

        pub fn reset(self: *AStar) void {
            // std.PriorityQueue does not have a clear() method...
            while (self.openSet.count() != 0) {
                _ = self.openSet.remove();
            }
            self.gScore.clearRetainingCapacity();
            self.cameFrom.clearRetainingCapacity();
        }

        pub fn run(self: *AStar, module: *Module, src: Pos, tgt: Pos) !usize {
            try self.gScore.put(src, 0);
            try self.openSet.add(StateDist.init(src, src.manhattanDistance(tgt)));
            while (self.openSet.count() != 0) {
                const sd = self.openSet.remove();
                const u = sd.state;
                if (u.equals(tgt)) {
                    return sd.dist;
                }

                var du: usize = INFINITY;
                if (self.gScore.get(u)) |d| {
                    du = d;
                }
                const cost = 1;
                for (Dirs) |dir| {
                    var ix: isize = @intCast(u.x);
                    var iy: isize = @intCast(u.y);
                    dir.movePos(&ix, &iy);
                    if (ix < 0 or ix >= module.cols) continue;
                    if (iy < 0 or iy >= module.rows) continue;
                    const nx: usize = @intCast(ix);
                    const ny: usize = @intCast(iy);
                    if (module.grid[nx][ny] != '.') continue;

                    const v = Pos.init(nx, ny);
                    var dv: usize = INFINITY;
                    if (self.gScore.get(v)) |d| {
                        dv = d;
                    }
                    const tentative = du + cost;
                    if (tentative >= dv) continue;

                    const estimate = v.manhattanDistance(module.end);
                    try self.cameFrom.put(v, u);
                    try self.gScore.put(v, tentative);
                    try self.openSet.add(StateDist.init(v, tentative + estimate));
                }
            }
            return INFINITY;
        }
    };

    allocator: Allocator,
    grid: [SIZE][SIZE]u8,
    rows: usize,
    cols: usize,
    bytes: std.ArrayList(Pos),
    start: Pos,
    end: Pos,
    fmt_buf: [100]u8,
    fmt_len: usize,
    search: AStar,

    pub fn init(allocator: Allocator, in_test: bool) Module {
        const max: usize = if (in_test) MAX_TEST else MAX_DAY;
        return .{
            .allocator = allocator,
            .grid = undefined,
            .rows = max + 1,
            .cols = max + 1,
            .bytes = std.ArrayList(Pos).init(allocator),
            .start = Pos.init(0, 0),
            .end = Pos.init(max, max),
            .fmt_buf = undefined,
            .fmt_len = 0,
            .search = AStar.init(allocator),
        };
    }

    pub fn deinit(self: *Module) void {
        self.search.deinit();
        self.bytes.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ',');
        const x = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        const y = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        try self.bytes.append(Pos.init(x, y));
    }

    // pub fn show(self: Module) void {
    //     std.debug.print("RAM: {}x{}, start {}, end {}\n", .{
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

    pub fn getSteps(self: *Module, bytes: usize) !usize {
        for (0..self.rows) |y| {
            for (0..self.cols) |x| {
                self.grid[x][y] = '.';
            }
        }
        for (0..bytes) |p| {
            const pos = self.bytes.items[p];
            self.grid[pos.x][pos.y] = '#';
        }
        // self.show();

        self.search.reset();
        const steps = try self.search.run(self, self.start, self.end);
        return steps;
    }

    pub fn findFirstBlockingByte(self: *Module) ![]const u8 {
        var bot: usize = 0;
        var top: usize = self.bytes.items.len - 1;
        var first = top;
        while (bot <= top) {
            const mid = (bot + top) / 2;
            const steps = try self.getSteps(mid + 1);
            if (steps == INFINITY) {
                if (first > mid) {
                    first = mid;
                }
                top = mid - 1;
            } else {
                bot = mid + 1;
            }
        }

        const pos = self.bytes.items[first];
        const buf = try std.fmt.bufPrint(&self.fmt_buf, "{},{}", .{ pos.x, pos.y });
        return buf;
    }
};

test "sample part 1" {
    const data =
        \\5,4
        \\4,2
        \\4,5
        \\3,0
        \\2,1
        \\6,3
        \\2,4
        \\1,5
        \\0,6
        \\3,3
        \\2,6
        \\5,1
        \\1,2
        \\5,5
        \\2,5
        \\6,5
        \\1,4
        \\0,4
        \\6,4
        \\1,1
        \\6,1
        \\1,0
        \\0,5
        \\1,6
        \\2,0
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getSteps(12);
    const expected = @as(usize, 22);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\5,4
        \\4,2
        \\4,5
        \\3,0
        \\2,1
        \\6,3
        \\2,4
        \\1,5
        \\0,6
        \\3,3
        \\2,6
        \\5,1
        \\1,2
        \\5,5
        \\2,5
        \\6,5
        \\1,4
        \\0,4
        \\6,4
        \\1,1
        \\6,1
        \\1,0
        \\0,5
        \\1,6
        \\2,0
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.findFirstBlockingByte();
    const expected = "6,1";
    try testing.expectEqualStrings(expected, count);
}
