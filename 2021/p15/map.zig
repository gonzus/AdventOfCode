const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

// TIMES
//
// Dijkstra optimized:
//   part 1: 0.037 seconds (answer: 707)
//   part 2: 0.719 seconds (answer: 2942)
//
// A*:
//   part 1: 0.052 seconds (answer: 707)
//   part 2: 1.034 seconds (answer: 2942)
pub const Map = struct {
    pub const Mode = enum { Small, Large };
    pub const Algo = enum { Dijkstra, AStar };

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            var self = Pos{ .x = x, .y = y };
            return self;
        }

        pub fn deinit(_: *Pos) void {}

        pub fn equal(self: Pos, other: Pos) bool {
            return self.x == other.x and self.y == other.y;
        }
    };

    const Node = struct {
        pos: Pos,
        cost: usize,

        pub fn init(pos: Pos, cost: usize) Node {
            var self = Node{ .pos = pos, .cost = cost };
            return self;
        }

        fn lessThan(l: Node, r: Node) std.math.Order {
            return std.math.order(l.cost, r.cost);
        }
    };

    const Dir = enum { N, S, E, W };

    const Path = std.AutoHashMap(Pos, Node);

    mode: Mode,
    algo: Algo,
    enlarged: bool,
    width: usize,
    height: usize,
    grid: std.AutoHashMap(Pos, usize),

    pub fn init(mode: Mode, algo: Algo) Map {
        var self = Map{
            .mode = mode,
            .algo = algo,
            .enlarged = false,
            .width = 0,
            .height = 0,
            .grid = std.AutoHashMap(Pos, usize).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.grid.deinit();
    }

    pub fn process_line(self: *Map, data: []const u8) !void {
        if (self.width == 0) self.width = data.len;
        if (self.width != data.len) unreachable;
        const y = self.height;
        for (data) |num, x| {
            const n = num - '0';
            const p = Pos.init(x, y);
            try self.grid.put(p, n);
        }
        self.height += 1;
    }

    pub fn get_total_risk(self: *Map) !usize {
        if (self.mode == Mode.Large and !self.enlarged) {
            try self.enlarge();
            self.enlarged = true;
        }
        const start = Pos.init(0, 0);
        const goal = Pos.init(self.width - 1, self.height - 1);
        var cameFrom = Path.init(allocator);
        defer cameFrom.deinit();
        switch (self.algo) {
            Algo.Dijkstra => try self.walk_dijkstra(start, goal, &cameFrom),
            Algo.AStar => try self.walk_astar(start, goal, &cameFrom),
        }

        var risk: usize = 0;
        var pos = goal;
        while (true) {
            // std.debug.warn("PATH {}\n", .{pos});
            if (pos.equal(start)) break;
            risk += self.grid.get(pos).?;
            const node = cameFrom.get(pos).?;
            pos = node.pos;
        }
        // std.debug.warn("SHORTEST {}\n", .{risk});
        return risk;
    }

    fn walk_dijkstra(self: *Map, start: Pos, goal: Pos, cameFrom: *Path) !void {
        var pending = std.PriorityQueue(Node, Node.lessThan).init(allocator);
        defer pending.deinit();
        var score = std.AutoHashMap(Pos, usize).init(allocator);
        defer score.deinit();

        // We begin the route at the start node
        try pending.add(Node.init(start, 0));
        while (pending.count() != 0) {
            const min_node = pending.remove();
            const u: Pos = min_node.pos;
            if (u.equal(goal)) {
                // found target -- yay!
                break;
            }
            const su = min_node.cost;

            // update score for all neighbours of u
            // add closest neighbour of u to the path
            for (std.enums.values(Dir)) |dir| {
                if (self.get_neighbor(u, dir)) |v| {
                    const duv = self.grid.get(v).?;
                    const tentative = su + duv;
                    var sv: usize = std.math.maxInt(usize);
                    if (score.getEntry(v)) |e| {
                        sv = e.value_ptr.*;
                    }
                    if (tentative >= sv) continue;
                    try pending.add(Node.init(v, tentative));
                    try score.put(v, tentative);
                    try cameFrom.put(v, Node.init(u, duv));
                }
            }
        }
    }

    // Implemented this because I thought it would make a major difference with
    // Dijkstra (back when the code was NOT using a priority queue), but there
    // is actually not much difference. and this is much more complicated.
    fn walk_astar(self: *Map, start: Pos, goal: Pos, cameFrom: *Path) !void {
        var pending = std.PriorityQueue(Node, Node.lessThan).init(allocator);
        defer pending.deinit();
        var gScore = std.AutoHashMap(Pos, usize).init(allocator);
        defer gScore.deinit();
        var hScore = std.AutoHashMap(Pos, usize).init(allocator);
        defer hScore.deinit();

        // Fill hScore for all nodes
        // fScore and gScore are infinite by default
        var y: usize = 0;
        while (y < self.height) : (y += 1) {
            var x: usize = 0;
            while (x < self.width) : (x += 1) {
                const p = Pos.init(x, y);
                try hScore.put(p, self.height - y + self.width - x);
            }
        }

        try gScore.put(start, 0);
        try pending.add(Node.init(start, 0));
        while (pending.count() != 0) {
            const min_node = pending.remove();
            const u: Pos = min_node.pos;
            if (u.equal(goal)) {
                // found target -- yay!
                break;
            }

            // update score for all neighbours of u
            // add closest neighbour of u to the path
            var gu: usize = std.math.maxInt(usize);
            if (gScore.getEntry(u)) |e| {
                gu = e.value_ptr.*;
            }
            for (std.enums.values(Dir)) |dir| {
                if (self.get_neighbor(u, dir)) |v| {
                    const duv = self.grid.get(v).?;
                    const tentative = gu + duv;
                    var gv: usize = std.math.maxInt(usize);
                    if (gScore.getEntry(v)) |e| {
                        gv = e.value_ptr.*;
                    }
                    if (tentative >= gv) continue;
                    try pending.add(Node.init(v, tentative));
                    try gScore.put(v, tentative);
                    try cameFrom.put(v, Node.init(u, duv));
                }
            }
        }
    }

    fn enlarge(self: *Map) !void {
        var y: usize = 0;
        while (y < self.height) : (y += 1) {
            var x: usize = 0;
            while (x < self.width) : (x += 1) {
                const p = Pos.init(x, y);
                var m = self.grid.get(p).?;
                var dy: usize = 0;
                while (dy < 5) : (dy += 1) {
                    var n = m;
                    var dx: usize = 0;
                    while (dx < 5) : (dx += 1) {
                        const q = Pos.init(x + self.width * dx, y + self.height * dy);
                        // std.debug.warn("ENLARGE {} = {}\n", .{ q, n });
                        try self.grid.put(q, n);
                        n += 1;
                        if (n > 9) n = 1;
                    }
                    m += 1;
                    if (m > 9) m = 1;
                }
            }
        }
        self.width *= 5;
        self.height *= 5;
    }

    fn get_neighbor(self: *Map, u: Pos, dir: Dir) ?Pos {
        var dx: isize = 0;
        var dy: isize = 0;
        switch (dir) {
            Dir.N => dy = -1,
            Dir.S => dy = 1,
            Dir.E => dx = 1,
            Dir.W => dx = -1,
        }
        const sx = @intCast(isize, u.x) + dx;
        if (sx < 0 or sx >= self.width) return null;
        const sy = @intCast(isize, u.y) + dy;
        if (sy < 0 or sy >= self.height) return null;
        var v = Pos.init(@intCast(usize, sx), @intCast(usize, sy));
        if (!self.grid.contains(v)) return null;
        return v;
    }
};

test "sample gonzo Dijkstra" {
    const data: []const u8 =
        \\1199
        \\9199
        \\1199
        \\1999
        \\1111
    ;

    var map = Map.init(Map.Mode.Small, Map.Algo.Dijkstra);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    const risk = try map.get_total_risk();
    try testing.expect(risk == 9);
}

test "sample gonzo A*" {
    const data: []const u8 =
        \\1199
        \\9199
        \\1199
        \\1999
        \\1111
    ;

    var map = Map.init(Map.Mode.Small, Map.Algo.AStar);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    const risk = try map.get_total_risk();
    try testing.expect(risk == 9);
}

test "sample part a Dijkstra" {
    const data: []const u8 =
        \\1163751742
        \\1381373672
        \\2136511328
        \\3694931569
        \\7463417111
        \\1319128137
        \\1359912421
        \\3125421639
        \\1293138521
        \\2311944581
    ;

    var map = Map.init(Map.Mode.Small, Map.Algo.Dijkstra);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    const risk = try map.get_total_risk();
    try testing.expect(risk == 40);
}

test "sample part a A*" {
    const data: []const u8 =
        \\1163751742
        \\1381373672
        \\2136511328
        \\3694931569
        \\7463417111
        \\1319128137
        \\1359912421
        \\3125421639
        \\1293138521
        \\2311944581
    ;

    var map = Map.init(Map.Mode.Small, Map.Algo.AStar);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    const risk = try map.get_total_risk();
    try testing.expect(risk == 40);
}

test "sample part b Dijkstra" {
    const data: []const u8 =
        \\1163751742
        \\1381373672
        \\2136511328
        \\3694931569
        \\7463417111
        \\1319128137
        \\1359912421
        \\3125421639
        \\1293138521
        \\2311944581
    ;

    var map = Map.init(Map.Mode.Large, Map.Algo.Dijkstra);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    const risk = try map.get_total_risk();
    try testing.expect(risk == 315);
}

test "sample part b A*" {
    const data: []const u8 =
        \\1163751742
        \\1381373672
        \\2136511328
        \\3694931569
        \\7463417111
        \\1319128137
        \\1359912421
        \\3125421639
        \\1293138521
        \\2311944581
    ;

    var map = Map.init(Map.Mode.Large, Map.Algo.AStar);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    const risk = try map.get_total_risk();
    try testing.expect(risk == 315);
}
