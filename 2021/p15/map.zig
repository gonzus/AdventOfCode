const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

// TIMES
//
// Dijkstra optimized:
//   part 1: 0.3 seconds (answer: 707)
//   part 2: 104 seconds (answer: 2942)
//
// A*:
//   part 1: 0.5 seconds (answer: 707)
//   part 2: 122 seconds (answer: 2942)
pub const Map = struct {
    pub const Mode = enum { Small, Large };
    pub const Algo = enum { Dijkstra, AStar };

    const Path = std.AutoHashMap(Pos, Pos);

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

    const Dir = enum { N, S, E, W };

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
            pos = cameFrom.get(pos).?;
        }
        // std.debug.warn("SHORTEST {}\n", .{risk});
        return risk;
    }

    fn walk_dijkstra(self: *Map, start: Pos, goal: Pos, cameFrom: *Path) !void {
        var pending = std.AutoHashMap(Pos, void).init(allocator);
        defer pending.deinit();
        var score = std.AutoHashMap(Pos, usize).init(allocator);
        defer score.deinit();

        // Fill score for all nodes
        var y: usize = 0;
        while (y < self.height) : (y += 1) {
            var x: usize = 0;
            while (x < self.width) : (x += 1) {
                const p = Pos.init(x, y);
                try score.put(p, std.math.maxInt(usize));
            }
        }

        // We begin the route at the start node
        try score.put(start, 0);
        try pending.put(start, {});
        while (pending.count() != 0) {
            // Search for a pending position with lowest score.
            // TODO: we could use a PriorityQueue here to quickly get at the
            // node, but we will also need to update the node's score later,
            // which would mean re-shuffling the PQ; not sure how to do this.
            var u: Pos = undefined;
            var smin: usize = std.math.maxInt(usize);
            var it = pending.iterator();
            while (it.next()) |pe| {
                const p = pe.key_ptr.*;
                if (score.getEntry(p)) |se| {
                    if (smin > se.value_ptr.*) {
                        smin = se.value_ptr.*;
                        u = se.key_ptr.*;
                    }
                }
            }

            _ = pending.remove(u);
            if (u.equal(goal)) break;

            // std.debug.warn("TRY {}\n", .{u});

            // update score for all neighbours of u
            // add closest neighbour of u to the path
            const su = score.get(u).?;
            for (std.enums.values(Dir)) |dir| {
                if (self.get_neighbor(u, dir)) |v| {
                    const duv = self.grid.get(v).?;
                    const tentative = su + duv;
                    const sv = score.get(v).?;
                    if (tentative >= sv) continue;
                    try pending.put(v, {});
                    try score.put(v, tentative);
                    try cameFrom.put(v, u);
                }
            }
        }
    }

    fn walk_astar(self: *Map, start: Pos, goal: Pos, cameFrom: *Path) !void {
        var pending = std.AutoHashMap(Pos, void).init(allocator);
        defer pending.deinit();
        var fScore = std.AutoHashMap(Pos, usize).init(allocator);
        defer fScore.deinit();
        var gScore = std.AutoHashMap(Pos, usize).init(allocator);
        defer gScore.deinit();
        var hScore = std.AutoHashMap(Pos, usize).init(allocator);
        defer hScore.deinit();

        // Fill fScore, gScore and hScore for all nodes
        var y: usize = 0;
        while (y < self.height) : (y += 1) {
            var x: usize = 0;
            while (x < self.width) : (x += 1) {
                const p = Pos.init(x, y);
                try gScore.put(p, std.math.maxInt(usize));
                try fScore.put(p, std.math.maxInt(usize));
                try hScore.put(p, self.height - y + self.width - x);
            }
        }

        // We begin the route at the start node
        const g = 0;
        const h = hScore.get(start).?;
        try fScore.put(start, g + h);
        try gScore.put(start, g);
        try pending.put(start, {});
        while (pending.count() != 0) {
            // Search for a pending position with lowest fScore.
            // TODO: we could use a PriorityQueue here to quickly get at the
            // node, but we will also need to update the node's score later,
            // which would mean re-shuffling the PQ; not sure how to do this.
            var u: Pos = undefined;
            var smin: usize = std.math.maxInt(usize);
            var it = pending.iterator();
            while (it.next()) |pe| {
                const p = pe.key_ptr.*;
                if (fScore.getEntry(p)) |se| {
                    if (smin > se.value_ptr.*) {
                        smin = se.value_ptr.*;
                        u = se.key_ptr.*;
                    }
                }
            }

            _ = pending.remove(u);
            if (u.equal(goal)) break;

            // std.debug.warn("TRY {}\n", .{u});

            // update score for all neighbours of u
            // add closest neighbour of u to the path
            const gu = gScore.get(u).?;
            for (std.enums.values(Dir)) |dir| {
                if (self.get_neighbor(u, dir)) |v| {
                    const duv = self.grid.get(v).?;
                    const tentative = gu + duv;
                    const gv = gScore.get(v).?;
                    if (tentative >= gv) continue;
                    const hv = hScore.get(v).?;
                    try cameFrom.put(v, u);
                    try gScore.put(v, tentative);
                    try fScore.put(v, tentative + hv);
                    try pending.put(v, {});
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
