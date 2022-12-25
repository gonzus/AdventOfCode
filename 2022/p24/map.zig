const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Map = struct {
    const INFINITY = std.math.maxInt(u32);
    const MAX_WIDTH = 120;
    const MAX_HEIGHT = 25;

    const Wind = enum(u8) {
        D = 0x01,
        L = 0x02,
        U = 0x04,
        R = 0x08,

        pub fn parse(c: u8) Cell {
            return switch (c) {
                'v' => .D,
                '<' => .L,
                '^' => .U,
                '>' => .R,
                else => unreachable,
            };
        }
    };

    const Cell = enum(u8) {
        Empty = '.',
        Wall  = '#',
        Elf  = 'E',

        pub fn parse(c: u8) Cell {
            return switch (c) {
                '.' => .Empty,
                '#' => .Elf,
                else => unreachable,
            };
        }
    };

    const Pos = struct {
        x: isize,
        y: isize,

        pub fn init(x: isize, y: isize) Pos {
            return Pos{.x = x, .y = y};
        }

        pub fn move(self: Pos, dx: isize, dy: isize, maxx: usize, maxy: usize) ?Pos {
            const vx = self.x + dx;
            if (vx < 0 or vx >= maxx) return null;
            const vy = self.y + dy;
            if (vy < 0 or vy >= maxy) return null;
            return Pos.init(vx, vy);
        }
    };

    const State = struct {
        pos: Pos,
        cycle: usize,

        pub fn init(pos: Pos, cycle: usize) State {
            return State{.pos = pos, .cycle = cycle};
        }
    };

    allocator: Allocator,
    winds: [MAX_WIDTH][MAX_HEIGHT]u8,
    cycles: std.ArrayList([MAX_WIDTH][MAX_HEIGHT]u8),
    expedition: Pos,
    enter: usize,
    exit: usize,
    rows: usize,
    cols: usize,
    max: Pos,

    pub fn init(allocator: Allocator) Map {
        var self = Map{
            .allocator = allocator,
            .winds = undefined,
            .cycles = std.ArrayList([MAX_WIDTH][MAX_HEIGHT]u8).init(allocator),
            .expedition = undefined,
            .enter = 0,
            .exit = 0,
            .rows = 0,
            .cols = 0,
            .max = Pos.init(0, 0),
        };
        var y: usize = 0;
        while (y < MAX_HEIGHT) : (y += 1) {
            var x: usize = 0;
            while (x < MAX_WIDTH) : (x += 1) {
                self.winds[x][y] = 0;
            }
        }
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.cycles.deinit();
    }

    pub fn add_line(self: *Map, line: []const u8) !void {
        if (self.cols == 0) {
            self.cols = line.len;
            self.enter = 0;
            self.exit = 0;
            self.max.x = self.cols - 2;
        }
        if (self.cols != line.len) unreachable;
        const y = self.rows;
        for (line) |c, x| {
            switch (c) {
                '#' => {},
                '.' => {
                    if (y == 0 and self.enter == 0) self.enter = x-1;
                    self.exit = x-1;
                },
                '^' => self.winds[x-1][y-1] |= @enumToInt(Wind.U),
                '>' => self.winds[x-1][y-1] |= @enumToInt(Wind.R),
                'v' => self.winds[x-1][y-1] |= @enumToInt(Wind.D),
                '<' => self.winds[x-1][y-1] |= @enumToInt(Wind.L),
                else => unreachable,
            }
        }
        self.rows += 1;
        if (self.rows > 2) self.max.y = self.rows - 2;
    }

    pub fn show(self: Map) void {
        std.debug.print("-- Map: {}x{} ------\n", .{self.max.x, self.max.y});
        std.debug.print("-- Enter: {}  Exit: {}  ----\n", .{self.enter, self.exit});
        var y: usize = 0;
        while (y < self.max.y) : (y += 1) {
            var x: usize = 0;
            while (x < self.max.x) : (x += 1) {
                const w = self.winds[x][y];
                var l: u8 = '.';
                var n: usize = 0;
                if (w & @enumToInt(Wind.U) > 0) {
                    n += 1;
                    l = '^';
                }
                if (w & @enumToInt(Wind.R) > 0) {
                    n += 1;
                    l = '>';
                }
                if (w & @enumToInt(Wind.D) > 0) {
                    n += 1;
                    l = 'v';
                }
                if (w & @enumToInt(Wind.L) > 0) {
                    n += 1;
                    l = '<';
                }
                if (n <= 1) {
                    std.debug.print("{c}", .{l});
                } else {
                    std.debug.print("{}", .{n});
                }
            }
            std.debug.print("\n", .{});
        }
    }

    const Seen = struct {
        hash: std.AutoHashMap(State, void),

        pub fn init(allocator: std.mem.Allocator) Seen {
            var self = Seen{
                .hash = std.AutoHashMap(State, void).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Seen) void {
            self.hash.deinit();
        }

        pub fn contains(self: Seen, state: State) bool {
            return self.hash.contains(state);
        }

        pub fn containsMaybeAdd(self: *Seen, state: State) !bool {
            const result = try self.hash.getOrPut(state);
            return result.found_existing;
        }
    };

    const NodeDist = struct {
        state: State,
        dist: u32,

        pub fn init(state: State, dist: u32) NodeDist {
            return NodeDist{ .state = state, .dist = dist };
        }

        fn lessThan(context: void, l: NodeDist, r: NodeDist) std.math.Order {
            _ = context;
            return std.math.order(l.dist, r.dist);
        }
    };

    const Path = struct {
        src: State,
        path: std.AutoHashMap(State, NodeDist),

        pub fn init(src: State, allocator: std.mem.Allocator) Path {
            var self = Path{
                .src = src,
                .path = std.AutoHashMap(State, NodeDist).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Path) void {
            self.path.deinit();
        }

        pub fn clear(self: *Path) void {
            self.path.clearRetainingCapacity();
        }

        pub fn addSegment(self: *Path, src: State, tgt: State, dist: u32) !void {
            try self.path.put(tgt, NodeDist.init(src, dist));
        }

        pub fn totalCost(self: Path, tgt: State) !u32 {
            var total_cost: u32 = 0;
            var current = tgt;
            while (!std.meta.eql(current, self.src)) {
                std.debug.print("    PATH {}\n", .{current});
                if (self.path.getEntry(current)) |e| {
                    const whence = e.value_ptr.*;
                    const node = whence.state;
                    const dist = whence.dist;
                    current = node;
                    total_cost += dist;
                } else {
                    return 0;
                }
            }
            return total_cost;
        }
    };

    fn gcd(ca: usize, cb: usize) usize {
        var a = ca;
        var b = cb;
        while (b != 0) {
            const t = b;
            b = a % b;
            a = t;
        }
        return a;
    }

    fn lcm(a: usize, b: usize) usize {
        return (a * b) / gcd(a, b);
    }

    fn generate_winds(self: *Map) !void {
        const top = lcm(self.max.x, self.max.y);
        var work: [2][MAX_WIDTH][MAX_HEIGHT]u8 = undefined;
        var cycle: usize = 0;
        var pos: usize = 0;
        work[pos] = self.winds;
        while (cycle < top) : (cycle += 1) {
            const nxt = 1 - pos;

            if (true) {
                var y: usize = 0;
                while (y < self.max.y) : (y += 1) {
                    var x: usize = 0;
                    while (x < self.max.x) : (x += 1) {
                        work[nxt][x][y] = 0;
                    }
                }
            }

            if (true) {
                var y: usize = 0;
                while (y < self.max.y) : (y += 1) {
                    var x: usize = 0;
                    while (x < self.max.x) : (x += 1) {
                        const w = work[pos][x][y];
                        if (w & @enumToInt(Wind.U) > 0) {
                            const nx = x;
                            const ny = (y + self.max.y - 1) % self.max.y;
                            work[nxt][nx][ny] |= @enumToInt(Wind.U);
                        }
                        if (w & @enumToInt(Wind.R) > 0) {
                            const nx = (x + self.max.x + 1) % self.max.x;
                            const ny = y;
                            work[nxt][nx][ny] |= @enumToInt(Wind.R);
                        }
                        if (w & @enumToInt(Wind.D) > 0) {
                            const nx = x;
                            const ny = (y + self.max.y + 1) % self.max.y;
                            work[nxt][nx][ny] |= @enumToInt(Wind.D);
                        }
                        if (w & @enumToInt(Wind.L) > 0) {
                            const nx = (x + self.max.x - 1) % self.max.x;
                            const ny = y;
                            work[nxt][nx][ny] |= @enumToInt(Wind.L);
                        }
                    }
                }
            }

            if (true) {
                std.debug.print("Winds for cycle {}:\n", .{cycle});
                var y: usize = 0;
                while (y < self.max.y) : (y += 1) {
                    var x: usize = 0;
                    while (x < self.max.x) : (x += 1) {
                        const w = work[nxt][x][y];
                        var l: u8 = '.';
                        var n: usize = 0;
                        if (w & @enumToInt(Wind.U) > 0) {
                            n += 1;
                            l = '^';
                        }
                        if (w & @enumToInt(Wind.R) > 0) {
                            n += 1;
                            l = '>';
                        }
                        if (w & @enumToInt(Wind.D) > 0) {
                            n += 1;
                            l = 'v';
                        }
                        if (w & @enumToInt(Wind.L) > 0) {
                            n += 1;
                            l = '<';
                        }
                        if (n <= 1) {
                            std.debug.print("{c}", .{l});
                        } else {
                            std.debug.print("{}", .{n});
                        }
                    }
                    std.debug.print("\n", .{});
                }
            }

            try self.cycles.append(work[nxt]);
            pos = nxt;
        }
        std.debug.print("GENERATED winds: {} cycles\n", .{self.cycles.items.len});
    }

    const Delta = struct {
        dx: i32,
        dy: i32,
    };
    const deltas = [_]Delta{
        .{.dx = -1, .dy =  0},
        .{.dx =  1, .dy =  0},
        .{.dx =  0, .dy =  0},
        .{.dx =  0, .dy = -1},
        .{.dx =  0, .dy =  1},
    };

    // TODO: this should probably become A*
    fn dijkstra(self: *Map, cycle: usize) !u32 {
        var distance = std.AutoHashMap(State, u32).init(self.allocator); // total distance so far to reach a node
        defer distance.deinit();
        var estimated = std.AutoHashMap(State, u32).init(self.allocator); // total distance so far to reach a node
        defer estimated.deinit();
        var visited = Seen.init(self.allocator); // nodes we have already visited
        defer visited.deinit();
        var pending = std.PriorityQueue(NodeDist, void, NodeDist.lessThan).init(self.allocator, {}); // pending nodes to visit
        defer pending.deinit();

        const src = Pos.init(self.enter, 0);
        const tgt = Pos.init(self.exit, self.max.y-1);

        var path = Path.init(State.init(src, cycle), self.allocator); // reverse path from a node to the source
        defer path.deinit();

        const src_state = State.init(src, cycle);
        try distance.put(src_state, 0);
        try estimated.put(src_state, @intCast(u32, self.exit + self.max.y));
        var found = false;
        var tgt_state: State = undefined;
        try pending.add(NodeDist.init(src_state, @intCast(u32, self.exit + self.max.y)));
        while (pending.count() != 0) {
            const nd = pending.remove();
            const u_state = nd.state;
            const u_pos = u_state.pos;
            var du: u32 = INFINITY;
            if (distance.get(u_state)) |d| {
                du = d;
            }
            std.debug.print("  Considering node {}, so far distance={}\n", .{ u_state, du });
            if (std.meta.eql(u_pos, tgt)) {
                std.debug.print("  Found target: {}\n", .{u_state});
                found = true;
                tgt_state = u_state;
                break; // found target!
            }
            _ = try visited.containsMaybeAdd(u_state);

            var c: usize = cycle;
            var waited: u32 = 0;
            while (true) {
                waited += 1;
                c += 1;
                c %= self.cycles.items.len;
                // if (c == cycle) break;
                const wind = self.cycles.items[c];

                for (deltas) |delta| {
                    const new = u_pos.move(delta.dx, delta.dy, self.max.x, self.max.y);
                    if (new == null) continue;
                    const v_pos = new.?;
                    if (wind[v_pos.x][v_pos.y] > 0) continue; // cannot move there

                    const v_state = State.init(v_pos, c);
                    if (visited.contains(v_state)) continue; // already was there

                    var dist_uv: u32 = waited;
                    // if (delta.dx != 0 or delta.dy != 0) dist_uv += 1;
                    const tentative: u32 = du + dist_uv;
                    var dv: u32 = INFINITY;
                    if (distance.get(v_state)) |d| {
                        dv = d;
                    }
                    if (tentative >= dv) continue;

                    try distance.put(v_state, tentative);

                    const diff = @intCast(u32, self.exit - v_pos.x + self.max.y - v_pos.y);
                    const score = tentative + diff;
                    try estimated.put(v_state, score);
                    // in theory we should update the distance for v in pending, but this is O(n), so we simply add a new element which will have the updated (lower) distance
                    // try pending.update(NodeDist.init(v_id, dv), NodeDist.init(v_id, tentative));
                    try pending.add(NodeDist.init(v_state, score));
                    try path.addSegment(u_state, v_state, dist_uv);
                    std.debug.print("    Added pending node {} with dist {}\n", .{v_state, score});
                }
                break;
            }
        }

        var best: u32 = INFINITY;
        if (found) {
            const cost = try path.totalCost(tgt_state);
            if (cost > 0) best = cost;
        }
        std.debug.print("DIJKSTRA from {} to {} with cycle {} => {}\n", .{ src, tgt, cycle, best});
        return best;
    }

    pub fn find_route(self: *Map) !u32 {
        try self.generate_winds();
        var best: u32 = INFINITY;
        for (self.cycles.items) |_, cycle| {
            // const cost = @intCast(u32, cycle) + try self.dijkstra(cycle) + 2;
            const cost = try self.dijkstra(cycle);
            if (best > cost) best = cost;
        }
        return best;
    }
};

test "sample part 1" {
    std.debug.print("\n", .{});
    const data: []const u8 =
        \\#.######
        \\#>>.<^<#
        \\#.<..<<#
        \\#>v.><>#
        \\#<^v^^>#
        \\######.#
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.add_line(line);
    }
    map.show();

    const cost = try map.find_route();
    try testing.expectEqual(@as(u32, 18), cost);
}
