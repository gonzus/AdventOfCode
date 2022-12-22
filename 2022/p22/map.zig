const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Map = struct {
    const INFINITY = std.math.maxInt(usize);

    const Turn = enum(u8) {
        L = 'L',
        R = 'R',

        pub fn parse(c: u8) Turn {
            return switch (c) {
                'L' => .L,
                'R' => .R,
                else => unreachable,
            };
        }
    };

    const Dir = enum(u8) {
        R = 0,
        D = 1,
        L = 2,
        U = 3,

        pub fn debug(self: Dir) u8 {
            return switch (self) {
                .L => '<',
                .U => '^',
                .R => '>',
                .D => 'v',
            };
        }

        pub fn turn(self: Dir, t: Turn) Dir {
            switch (self) {
                .L => return switch(t) {
                    .L => .D,
                    .R => .U,
                },
                .R => return switch(t) {
                    .L => .U,
                    .R => .D,
                },
                .U => return switch(t) {
                    .L => .L,
                    .R => .R,
                },
                .D => return switch(t) {
                    .L => .R,
                    .R => .L,
                },
            }
        }

        pub fn opposite(self: Dir) Dir {
            return switch (self) {
                .L => .R,
                .U => .D,
                .R => .L,
                .D => .U,
            };
        }
    };

    const ActionTag = enum {
        Walk,
        Turn,
    };

    const Action = union(ActionTag) {
        Walk: usize,
        Turn: Turn,
    };

    const Cell = enum(u8) {
        Empty = '.',
        Wall  = '#',

        pub fn parse(c: u8) Cell {
            return switch (c) {
                '.' => .Empty,
                '#' => .Wall,
                else => unreachable,
            };
        }
    };

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            return Pos{.x = x, .y = y};
        }

        pub fn step(self: Pos, dir: Dir, size: Pos) Pos {
            var dx: isize = 0;
            var dy: isize = 0;
            switch (dir) {
                .L => dx = -1,
                .R => dx = 1,
                .U => dy = -1,
                .D => dy = 1,
            }

            // gonzo: plus FUCKING one!
            const maxx = size.x + 1;
            const maxy = size.y + 1;
            const x = @intCast(usize, @intCast(isize, self.x + maxx) + dx) % maxx;
            const y = @intCast(usize, @intCast(isize, self.y + maxy) + dy) % maxy;
            return Pos.init(x, y);
        }
    };

    const State = struct {
        pos: Pos,
        dir: Dir,
    };

    grid: std.AutoHashMap(Pos, Cell),
    actions: std.ArrayList(Action),
    part: usize,
    rows: usize,
    min: Pos,
    max: Pos,
    start: State,
    current: State,
    edges: std.AutoHashMap(State, State),

    pub fn init(allocator: Allocator) Map {
        var self = Map{
            .grid = std.AutoHashMap(Pos, Cell).init(allocator),
            .actions = std.ArrayList(Action).init(allocator),
            .part = 0,
            .rows = 0,
            .min = Pos.init(INFINITY, INFINITY),
            .max = Pos.init(0, 0),
            .start = undefined,
            .current = undefined,
            .edges = std.AutoHashMap(State, State).init(allocator),
        };
        self.start = State{.pos = Pos.init(INFINITY, INFINITY), .dir = .R};
        self.current = self.start;
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.edges.deinit();
        self.actions.deinit();
        self.grid.deinit();
    }

    fn get_pos(self: Map, pos: Pos) ?Cell {
        return self.grid.get(pos);
    }

    fn set_pos(self: *Map, pos: Pos, cell: Cell) !void {
        try self.grid.put(pos, cell);
        if (cell == .Empty and (self.start.pos.x == INFINITY or self.start.pos.y == INFINITY)) {
            self.start.pos = pos;
            self.start.dir = .R;
            self.current = self.start;
        }
        if (self.min.x > pos.x) self.min.x = pos.x;
        if (self.min.y > pos.y) self.min.y = pos.y;
        if (self.max.x < pos.x) self.max.x = pos.x;
        if (self.max.y < pos.y) self.max.y = pos.y;
    }

    fn step(self: *Map) Pos {
        var nxt = self.current.pos;
        while (true) {
            const tmp = nxt.step(self.current.dir, self.max);
            if (self.grid.contains(tmp)) return tmp;
            nxt = tmp;
        }
        unreachable;
    }

    fn add_map(self: *Map, line: []const u8) !void {
        const y = self.rows;
        for (line) |c, x| {
            if (c == ' ') continue;
            const cell = Cell.parse(c);
            const pos = Pos.init(x, y);
            try self.set_pos(pos, cell);
        }
        self.rows += 1;
    }

    fn add_action(self: *Map, line: []const u8) !void {
        var action: Action = undefined;
        var p: usize = 0;
        while (p < line.len) : (p += 1) {
            var num: usize = 0;
            var q: usize = p;
            while (q < line.len) : (q += 1) {
                if (line[q] >= '0' and line[q] <= '9') {
                    num *= 10;
                    num += line[q] - '0';
                } else {
                    break;
                }
            }
            if (q == p) {
                const turn = Turn.parse(line[p]);
                action = Action{.Turn = turn};

            } else {
                action = Action{.Walk = num};
                p = q-1;
            }
            try self.actions.append(action);
        }
    }

    pub fn add_line(self: *Map, line: []const u8) !void {
        if (line.len == 0) {
            self.part += 1;
            return;
        }

        if (self.part == 0) return self.add_map(line);
        if (self.part == 1) return self.add_action(line);
        unreachable;
    }

    pub fn show(self: Map) void {
        std.debug.print("Start: {} facing {}\n", .{self.start.pos, self.start.dir});
        std.debug.print("Current: {} facing {}\n", .{self.current.pos, self.current.dir});
        std.debug.print("-- Map --------\n", .{});
        var y: usize = self.min.y;
        while (y <= self.max.y) : (y += 1) {
            var x: usize = self.min.x;
            while (x <= self.max.x) : (x += 1) {
                var c: u8 = ' ';
                const pos = Pos.init(x, y);
                if (self.get_pos(pos)) |cell| {
                    c = @enumToInt(cell);
                }
                if (pos.x == self.current.pos.x and pos.y == self.current.pos.y) {
                    c = self.current.dir.debug();
                }
                std.debug.print("{c}", .{c});
            }
            std.debug.print("\n", .{});
        }
        std.debug.print("-- Actions ----\n", .{});
        for (self.actions.items) |action, n| {
            if (n > 0) {
                std.debug.print(" ", .{});
            }
            switch (action) {
                .Walk => |w| std.debug.print("{}", .{w}),
                .Turn => |t| std.debug.print("{c}", .{@enumToInt(t)}),
            }
        }
        std.debug.print("\n", .{});
    }

    fn add_map_edge(self: *Map, x0: usize, y0: usize, dir0: Dir, x1: usize, y1: usize, dir1: Dir) !void {
        var src = State{.pos = Pos.init(x0, y0), .dir = dir0};
        var tgt = State{.pos = Pos.init(x1, y1), .dir = dir1};
        try self.edges.put(src, tgt);
        src.dir = src.dir.opposite();
        tgt.dir = tgt.dir.opposite();
        try self.edges.put(tgt, src);
    }

    fn populate_edges(self: *Map, cube: usize) !void {
        self.edges.clearRetainingCapacity();
        if (cube == 0) return;
        if (cube == 4) {
            // these are hard-coded for the test data
            var p: usize = 0;
            while (p < cube) : (p += 1) {
                try self.add_map_edge(   8,    p, .L,  4+p,    4, .D);
                try self.add_map_edge( 8+p,    0, .U,  3-p,    4, .D);
                try self.add_map_edge( 4+p,    7, .D,    8, 11-p, .R);
                try self.add_map_edge( 8+p,   11, .D,  3-p,    7, .U);
                try self.add_map_edge(  11,  4+p, .R, 15-p,    8, .D);
                try self.add_map_edge(  11,    p, .R,   15, 11-p, .L);
                try self.add_map_edge(   0,  4+p, .L, 15-p,   11, .U);
            }
            return;
        }
        if (cube == 50) {
            // these are hard-coded for gonzo's input -- sad
            var p: usize = 0;
            while (p < cube) : (p += 1) {
                try self.add_map_edge(100+p,    49, .D,    99,  50+p, .L); // D -> F
                try self.add_map_edge(  149,     p, .R,    99, 149-p, .L); // C -> H
                try self.add_map_edge(   50,  50+p, .L,     p,   100, .D); // G -> J
                try self.add_map_edge( 50+p,   149, .D,    49, 150+p, .L); // I -> N
                try self.add_map_edge(   50,     p, .L,     0, 149-p, .R); // E -> K
                try self.add_map_edge( 50+p,     0, .U,     0, 150+p, .R); // A -> L
                try self.add_map_edge(100+p,     0, .U,     p,   199, .U); // B -> M
            }
            return;
        }
        unreachable;
    }

    fn compute_password(self: *Map) !usize {
        const pr: usize = self.current.pos.y + 1;
        const pc: usize = self.current.pos.x + 1;
        const pd: usize = @enumToInt(self.current.dir);
        const value: usize = 1000 * pr + 4 * pc + pd;
        return value;
    }

    pub fn walk(self: *Map, cube: usize) !usize {
        try self.populate_edges(cube);
        self.current = self.start;
        for (self.actions.items) |action| {
            switch (action) {
                .Turn => |t| {
                    self.current.dir = self.current.dir.turn(t);
                },
                .Walk => |w| {
                    var n: usize = 0;
                    while (n < w) : (n += 1) {
                        var next = self.current;
                        if (self.edges.get(self.current)) |edge| {
                            next = edge;
                        } else {
                            next.pos = self.step();
                        }
                        if (self.get_pos(next.pos)) |cell| {
                            switch (cell) {
                                .Empty => {
                                    self.current = next;
                                },
                                .Wall => break,
                            }
                        } else {
                            unreachable;
                        }
                    }
                }
            }
            // self.show();
        }
        return self.compute_password();
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\        ...#
        \\        .#..
        \\        #...
        \\        ....
        \\...#.......#
        \\........#...
        \\..#....#....
        \\..........#.
        \\        ...#....
        \\        .....#..
        \\        .#......
        \\        ......#.
        \\
        \\10R5L5R10L4R5L5
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.add_line(line);
    }
    // map.show();

    const password = try map.walk(0);
    try testing.expectEqual(@as(usize, 6032), password);
}

test "sample part 2" {
    const data: []const u8 =
        \\        ...#
        \\        .#..
        \\        #...
        \\        ....
        \\...#.......#
        \\........#...
        \\..#....#....
        \\..........#.
        \\        ...#....
        \\        .....#..
        \\        .#......
        \\        ......#.
        \\
        \\10R5L5R10L4R5L5
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.add_line(line);
    }
    // map.show();

    const password = try map.walk(4);
    try testing.expectEqual(@as(usize, 5031), password);
}
