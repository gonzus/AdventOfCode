const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Graph = struct {
    const StringId = StringTable.StringId;
    const ITERATIONS = 500;
    const EDGES_TO_REMOVE = 3;
    const INVALID_NODE = std.math.maxInt(usize);

    const Edge = struct {
        src: StringId,
        tgt: StringId,

        pub fn init(src: StringId, tgt: StringId) Edge {
            return Edge{ .src = src, .tgt = tgt };
        }
    };

    const EdgeCount = struct {
        edge: Edge,
        count: usize,

        pub fn init(edge: Edge) EdgeCount {
            return EdgeCount{ .edge = edge, .count = 0 };
        }

        pub fn greaterThan(_: void, l: EdgeCount, r: EdgeCount) bool {
            return l.count > r.count;
        }
    };

    const Node = struct {
        id: StringId,
        neighbors: std.AutoHashMap(StringId, Edge),

        pub fn init(allocator: Allocator, id: StringId) Node {
            const self = Node{
                .id = id,
                .neighbors = std.AutoHashMap(StringId, Edge).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Node) void {
            self.neighbors.deinit();
        }

        pub fn addNeighbor(self: *Node, id: StringId) !void {
            var result = try self.neighbors.getOrPut(id);
            if (!result.found_existing) {
                result.value_ptr.* = Edge.init(self.id, id);
            }
        }

        pub fn removeNeighbor(self: *Node, id: StringId) !void {
            _ = self.neighbors.remove(id);
        }
    };

    const NodeDist = struct {
        node: StringId,
        dist: usize,

        pub fn init(node: StringId, dist: usize) NodeDist {
            return NodeDist{ .node = node, .dist = dist };
        }

        pub fn lessThan(_: void, l: NodeDist, r: NodeDist) std.math.Order {
            return std.math.order(l.dist, r.dist);
        }
    };

    allocator: Allocator,
    strtab: StringTable,
    nodes: std.AutoHashMap(StringId, Node),
    edges: std.ArrayList(EdgeCount), // need array to sort it later
    edges_map: std.AutoHashMap(Edge, usize),

    pub fn init(allocator: Allocator) Graph {
        return Graph{
            .allocator = allocator,
            .strtab = StringTable.init(allocator),
            .nodes = std.AutoHashMap(StringId, Node).init(allocator),
            .edges = std.ArrayList(EdgeCount).init(allocator),
            .edges_map = std.AutoHashMap(Edge, usize).init(allocator),
        };
    }

    pub fn deinit(self: *Graph) void {
        self.edges_map.deinit();
        self.edges.deinit();
        var it = self.nodes.valueIterator();
        while (it.next()) |*node| {
            node.*.deinit();
        }
        self.nodes.deinit();
        self.strtab.deinit();
    }

    fn addNode(self: *Graph, name: []const u8) !usize {
        const id = try self.strtab.add(name);
        var result = try self.nodes.getOrPut(id);
        if (!result.found_existing) {
            result.value_ptr.* = Node.init(self.allocator, id);
        }
        return id;
    }

    fn addEdge(self: *Graph, id0: usize, id1: usize) !void {
        const n0_maybe = self.nodes.getEntry(id0);
        const n1_maybe = self.nodes.getEntry(id1);
        if (n0_maybe) |n0| {
            if (n1_maybe) |n1| {
                try n0.value_ptr.*.addNeighbor(id1);
                try n1.value_ptr.*.addNeighbor(id0);
            }
        }
    }

    fn removeEdge(self: *Graph, id0: usize, id1: usize) !void {
        const ids = [_]usize{ id0, id1 };
        for (ids, 0..) |id, pos| {
            const node_maybe = self.nodes.getEntry(id);
            if (node_maybe) |node| {
                const other = ids[ids.len - pos - 1];
                try node.value_ptr.*.removeNeighbor(other);
            }
        }
    }

    pub fn addLine(self: *Graph, line: []const u8) !void {
        var it_nodes = std.mem.tokenizeAny(u8, line, ": ");
        var count: usize = 0;
        var src: usize = undefined;
        while (it_nodes.next()) |node| : (count += 1) {
            if (count == 0) {
                src = try self.addNode(node);
                continue;
            }
            const tgt = try self.addNode(node);
            try self.addEdge(src, tgt);
        }
    }

    pub fn show(self: Graph) void {
        std.debug.print("Graph: {} nodes\n", .{self.nodes.count()});
        var it = self.nodes.valueIterator();
        while (it.next()) |node| {
            std.debug.print("  {s}:", .{self.strtab.get_str(node.id) orelse "***"});
            var it_edges = node.neighbors.keyIterator();
            while (it_edges.next()) |edge| {
                std.debug.print(" {s}", .{self.strtab.get_str(edge.*) orelse "***"});
            }
            std.debug.print("\n", .{});
        }
    }

    const PQ = std.PriorityQueue(NodeDist, void, NodeDist.lessThan);

    fn walkFromTo(self: *Graph, src: usize, tgt: usize) !usize {
        var queue = PQ.init(self.allocator, {});
        defer queue.deinit();
        var seen = std.AutoHashMap(usize, void).init(self.allocator);
        defer seen.deinit();
        var path = std.AutoHashMap(usize, usize).init(self.allocator);
        defer path.deinit();

        try queue.add(NodeDist.init(src, 0));
        while (queue.count() > 0) {
            const nd = queue.remove();
            if (tgt != INVALID_NODE and nd.node == tgt) break;

            const node_maybe = self.nodes.get(nd.node);
            if (node_maybe) |node| {
                var it_edges = node.neighbors.valueIterator();
                while (it_edges.next()) |edge| {
                    if (edge.src != nd.node) return error.InvalidEdge;

                    const result = try seen.getOrPut(edge.tgt);
                    if (result.found_existing) continue;

                    try path.put(edge.tgt, edge.src);
                    try queue.add(NodeDist.init(edge.tgt, nd.dist + 1));
                }
            }
        }

        if (tgt != INVALID_NODE) {
            var node = tgt;
            while (true) {
                const parent_maybe = path.get(node);
                if (parent_maybe) |parent| {
                    const edge = if (node < parent) Edge.init(node, parent) else Edge.init(parent, node);
                    var result = try self.edges_map.getOrPut(edge);
                    var pos: usize = undefined;
                    if (result.found_existing) {
                        pos = result.value_ptr.*;
                    } else {
                        pos = self.edges.items.len;
                        try self.edges.append(EdgeCount.init(edge));
                        result.value_ptr.* = pos;
                    }
                    self.edges.items[pos].count += 1;
                    node = parent;
                    if (node == src) break;
                } else break;
            }
        }

        return seen.count();
    }

    pub fn getSubgraphSizeProduct(self: *Graph) !usize {
        const size = self.nodes.count();
        var random_generator = std.rand.DefaultPrng.init(0);
        var random = random_generator.random();
        for (0..ITERATIONS) |_| {
            const src = random.intRangeLessThan(usize, 0, size);
            var tgt = src;
            while (tgt == src) {
                tgt = random.intRangeLessThan(usize, 0, size);
            }
            _ = try self.walkFromTo(src, tgt);
        }

        std.sort.heap(EdgeCount, self.edges.items, {}, EdgeCount.greaterThan);

        for (self.edges.items, 0..) |ec, pos| {
            if (pos >= EDGES_TO_REMOVE) break;
            try self.removeEdge(ec.edge.src, ec.edge.tgt); // does not touch self.edges
        }

        const src = random.intRangeLessThan(usize, 0, size);
        const steps = try self.walkFromTo(src, INVALID_NODE);
        const remaining = size - steps;
        return steps * remaining;
    }
};

test "sample part 1" {
    const data =
        \\jqt: rhn xhk nvd
        \\rsh: frs pzl lsr
        \\xhk: hfx
        \\cmg: qnr nvd lhk bvb
        \\rhn: xhk bvb hfx
        \\bvb: xhk hfx
        \\pzl: lsr hfx nvd
        \\qnr: nvd
        \\ntq: jqt hfx bvb xhk
        \\nvd: lhk
        \\lsr: lhk
        \\rzs: qnr cmg lsr rsh
        \\frs: qnr lhk lsr
    ;

    var graph = Graph.init(std.testing.allocator);
    defer graph.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try graph.addLine(line);
    }
    // graph.show();

    const count = try graph.getSubgraphSizeProduct();
    const expected = @as(usize, 54);
    try testing.expectEqual(expected, count);
}
