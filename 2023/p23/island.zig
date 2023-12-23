const std = @import("std");
const testing = std.testing;
const Grid = @import("./util/grid.zig").Grid;
const Pos = @import("./util/grid.zig").Pos;

const Allocator = std.mem.Allocator;

pub const Map = struct {
    const Data = Grid(u8);

    const Dir = enum { U, D, L, R };
    const DIRS = [_]Dir{ .U, .D, .L, .R };

    const Edge = struct {
        target: usize,
        dist: usize,

        pub fn init(target: usize, dist: usize) Edge {
            return Edge{ .target = target, .dist = dist };
        }
    };

    const Node = struct {
        index: usize,
        pos: Pos,
        neighbors: std.ArrayList(Edge),
        seen: bool,

        pub fn init(allocator: Allocator, index: usize, pos: Pos) Node {
            return Node{
                .index = index,
                .pos = pos,
                .neighbors = std.ArrayList(Edge).init(allocator),
                .seen = false,
            };
        }

        pub fn deinit(self: *Node) void {
            self.neighbors.deinit();
        }

        pub fn addNeighbor(self: *Node, index: usize, dist: usize) !void {
            try self.neighbors.append(Edge.init(index, dist));
        }
    };

    const Graph = struct {
        allocator: Allocator,
        nodes: std.ArrayList(Node),
        locations: std.AutoHashMap(Pos, usize),

        pub fn init(allocator: Allocator) Graph {
            return Graph{
                .allocator = allocator,
                .nodes = std.ArrayList(Node).init(allocator),
                .locations = std.AutoHashMap(Pos, usize).init(allocator),
            };
        }

        pub fn deinit(self: *Graph) void {
            self.locations.deinit();
            for (self.nodes.items) |*node| {
                node.*.deinit();
            }
            self.nodes.deinit();
        }

        pub fn clear(self: *Graph) void {
            self.nodes.clearRetainingCapacity();
            self.locations.clearRetainingCapacity();
        }

        pub fn addNode(self: *Graph, pos: Pos) !usize {
            const index = self.nodes.items.len;
            try self.nodes.append(Node.init(self.allocator, index, pos));
            try self.locations.put(pos, index);
            return index;
        }

        pub fn joinNodes(self: *Graph, idx0: usize, idx1: usize, dist: usize) !void {
            try self.nodes.items[idx0].addNeighbor(idx1, dist);
            try self.nodes.items[idx1].addNeighbor(idx0, dist);
        }
    };

    allocator: Allocator,
    slippery: bool,
    grid: Data,
    start: Pos,
    end: Pos,
    graph: Graph,
    seen: std.AutoHashMap(Pos, void),
    longest: usize,

    pub fn init(allocator: Allocator, slippery: bool) Map {
        var self = Map{
            .allocator = allocator,
            .slippery = slippery,
            .grid = Data.init(allocator, '.'),
            .start = undefined,
            .end = undefined,
            .graph = Graph.init(allocator),
            .seen = std.AutoHashMap(Pos, void).init(allocator),
            .longest = 0,
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.seen.deinit();
        self.graph.deinit();
        self.grid.deinit();
    }

    pub fn clear(self: *Map) void {
        self.seen.clearRetainingCapacity();
        self.longest = 0;
    }

    pub fn addLine(self: *Map, line: []const u8) !void {
        try self.grid.ensureCols(line.len);
        try self.grid.ensureExtraRow();
        const y = self.grid.rows();
        for (line, 0..) |c, x| {
            const pos = Pos.init(x, y);
            try self.grid.set(pos.x, pos.y, c);
            if (c == '.') {
                self.end = Pos.init(x, y);
                if (y == 0) self.start = Pos.init(x, y);
            }
        }
    }

    pub fn show(self: Map) void {
        std.debug.print("Map: {} x {}, start {}, end {}\n", .{ self.grid.rows(), self.grid.cols(), self.start, self.end });
        for (0..self.grid.rows()) |y| {
            for (0..self.grid.cols()) |x| {
                const c = self.grid.get(x, y);
                std.debug.print("{c}", .{c});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn getLongestHike(self: *Map) !usize {
        self.clear();
        if (self.slippery) {
            try self.findAllPathsInMap(self.start, 0);
        } else {
            try self.buildGraph();
            try self.findAllPathsInGraph(0, 0);
        }
        return self.longest;
    }

    fn findAllPathsInMap(self: *Map, cpos: Pos, dist: usize) !void {
        if (cpos.equal(self.end)) {
            if (self.longest < dist) {
                self.longest = dist;
            }
            return;
        }
        try self.seen.put(cpos, {});
        defer _ = self.seen.remove(cpos);

        const cwhat = self.grid.get(cpos.x, cpos.y);
        for (DIRS) |dir| {
            const npos_maybe = self.moveDir(cpos, dir);
            if (npos_maybe) |npos| {
                const nwhat = self.grid.get(npos.x, npos.y);
                if (nwhat == '#') continue;
                if (self.seen.contains(npos)) continue;

                if (cwhat == '>' and dir == .R) {
                    try self.findAllPathsInMap(npos, dist + 1);
                    continue;
                }

                if (cwhat == '<' and dir == .L) {
                    try self.findAllPathsInMap(npos, dist + 1);
                    continue;
                }

                if (cwhat == '^' and dir == .U) {
                    try self.findAllPathsInMap(npos, dist + 1);
                    continue;
                }

                if (cwhat == 'v' and dir == .D) {
                    try self.findAllPathsInMap(npos, dist + 1);
                    continue;
                }

                if (cwhat == '.') {
                    try self.findAllPathsInMap(npos, dist + 1);
                    continue;
                }
            }
        }
    }

    fn buildGraph(self: *Map) !void {
        self.graph.clear();
        for (0..self.grid.rows()) |y| {
            for (0..self.grid.cols()) |x| {
                const cwhat = self.grid.get(x, y);
                if (cwhat == '#') continue;

                const cpos = Pos.init(x, y);
                if (cpos.equal(self.start) or cpos.equal(self.end)) {
                    _ = try self.graph.addNode(cpos);
                    continue;
                }

                var count: usize = 0;
                for (DIRS) |dir| {
                    const npos_maybe = self.moveDir(cpos, dir);
                    if (npos_maybe) |npos| {
                        const nwhat = self.grid.get(npos.x, npos.y);
                        if (nwhat == '#') continue;
                        count += 1;
                    }
                }
                if (count <= 2) continue;
                _ = try self.graph.addNode(cpos);
            }
        }
        for (self.graph.nodes.items) |node| {
            self.seen.clearRetainingCapacity();
            try self.walkFromNode(node, node.pos, 0);
        }
    }

    fn walkFromNode(self: *Map, node: Node, pos: Pos, dist: usize) !void {
        _ = try self.seen.put(pos, {});
        defer _ = self.seen.remove(pos);

        for (DIRS) |dir| {
            const npos_maybe = self.moveDir(pos, dir);
            if (npos_maybe) |npos| {
                if (self.grid.get(npos.x, npos.y) == '#') continue;
                if (self.seen.contains(npos)) continue;
                const entry = self.graph.locations.getEntry(npos);
                if (entry) |e| {
                    const other = self.graph.nodes.items[e.value_ptr.*];
                    if (other.index <= node.index) continue;
                    try self.graph.joinNodes(node.index, other.index, dist + 1);
                    continue;
                }
                try self.walkFromNode(node, npos, dist + 1);
            }
        }
    }

    fn findAllPathsInGraph(self: *Map, index: usize, dist: usize) !void {
        const node = self.graph.nodes.items[index];
        if (node.pos.equal(self.end)) {
            if (self.longest < dist) {
                self.longest = dist;
            }
            return;
        }
        self.graph.nodes.items[index].seen = true;
        defer self.graph.nodes.items[index].seen = false;

        for (node.neighbors.items) |e| {
            const neighbour = self.graph.nodes.items[e.target];
            if (neighbour.seen) continue;
            try self.findAllPathsInGraph(e.target, dist + e.dist);
        }
    }

    fn validMove(self: Map, pos: Pos, dir: Dir) bool {
        return switch (dir) {
            .U => pos.y > 0,
            .D => pos.y < self.grid.rows() - 1,
            .R => pos.x < self.grid.cols() - 1,
            .L => pos.x > 0,
        };
    }

    fn moveDir(self: Map, pos: Pos, dir: Dir) ?Pos {
        if (!self.validMove(pos, dir)) return null;
        switch (dir) {
            .U => return Pos.init(pos.x, pos.y - 1),
            .D => return Pos.init(pos.x, pos.y + 1),
            .R => return Pos.init(pos.x + 1, pos.y),
            .L => return Pos.init(pos.x - 1, pos.y),
        }
    }
};

test "sample part 1" {
    const data =
        \\#.#####################
        \\#.......#########...###
        \\#######.#########.#.###
        \\###.....#.>.>.###.#.###
        \\###v#####.#v#.###.#.###
        \\###.>...#.#.#.....#...#
        \\###v###.#.#.#########.#
        \\###...#.#.#.......#...#
        \\#####.#.#.#######.#.###
        \\#.....#.#.#.......#...#
        \\#.#####.#.#.#########v#
        \\#.#...#...#...###...>.#
        \\#.#.#v#######v###.###v#
        \\#...#.>.#...>.>.#.###.#
        \\#####v#.#.###v#.#.###.#
        \\#.....#...#...#.#.#...#
        \\#.#########.###.#.#.###
        \\#...###...#...#...#.###
        \\###.###.#.###v#####v###
        \\#...#...#.#.>.>.#.>.###
        \\#.###.###.#.###.#.#v###
        \\#.....###...###...#...#
        \\#####################.#
    ;

    var map = Map.init(std.testing.allocator, true);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }

    const count = try map.getLongestHike();
    const expected = @as(usize, 94);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\#.#####################
        \\#.......#########...###
        \\#######.#########.#.###
        \\###.....#.>.>.###.#.###
        \\###v#####.#v#.###.#.###
        \\###.>...#.#.#.....#...#
        \\###v###.#.#.#########.#
        \\###...#.#.#.......#...#
        \\#####.#.#.#######.#.###
        \\#.....#.#.#.......#...#
        \\#.#####.#.#.#########v#
        \\#.#...#...#...###...>.#
        \\#.#.#v#######v###.###v#
        \\#...#.>.#...>.>.#.###.#
        \\#####v#.#.###v#.#.###.#
        \\#.....#...#...#.#.#...#
        \\#.#########.###.#.#.###
        \\#...###...#...#...#.###
        \\###.###.#.###v#####v###
        \\#...#...#.#.>.>.#.>.###
        \\#.###.###.#.###.#.#v###
        \\#.....###...###...#...#
        \\#####################.#
    ;

    var map = Map.init(std.testing.allocator, false);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }

    const count = try map.getLongestHike();
    const expected = @as(usize, 154);
    try testing.expectEqual(expected, count);
}
