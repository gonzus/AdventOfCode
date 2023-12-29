const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Graph = struct {
    const StringId = StringTable.StringId;

    const Node = struct {
        name: StringId,
        neighbors: std.AutoHashMap(StringId, usize),

        pub fn init(allocator: Allocator, name: StringId) Node {
            return Node{
                .name = name,
                .neighbors = std.AutoHashMap(StringId, usize).init(allocator),
            };
        }

        pub fn deinit(self: *Node) void {
            self.neighbors.deinit();
        }
    };

    allocator: Allocator,
    shortest: bool,
    strtab: StringTable,
    nodes: std.AutoHashMap(StringId, Node),
    visited: std.AutoHashMap(StringId, void),
    best: usize,

    pub fn init(allocator: Allocator, shortest: bool) Graph {
        const self = Graph{
            .allocator = allocator,
            .shortest = shortest,
            .strtab = StringTable.init(allocator),
            .nodes = std.AutoHashMap(StringId, Node).init(allocator),
            .visited = std.AutoHashMap(StringId, void).init(allocator),
            .best = if (shortest) std.math.maxInt(usize) else std.math.minInt(usize),
        };
        return self;
    }

    pub fn deinit(self: *Graph) void {
        self.visited.deinit();
        var it = self.nodes.valueIterator();
        while (it.next()) |*node| {
            node.*.deinit();
        }
        self.nodes.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Graph, line: []const u8) !void {
        var src: StringId = undefined;
        var tgt: StringId = undefined;
        var dist: usize = 0;

        var pos: usize = 0;
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        while (it.next()) |chunk| : (pos += 1) {
            switch (pos) {
                0 => src = try self.strtab.add(chunk),
                2 => tgt = try self.strtab.add(chunk),
                4 => dist = try std.fmt.parseUnsigned(usize, chunk, 10),
                else => continue,
            }
        }

        try self.addRoute(src, tgt, dist);
    }

    pub fn show(self: Graph) void {
        std.debug.print("Graph with {} nodes\n", .{self.nodes.count()});
        var it = self.nodes.valueIterator();
        while (it.next()) |node| {
            std.debug.print("  {s} =>", .{
                self.strtab.get_str(node.name) orelse "***",
            });
            var it_neighbor = node.neighbors.iterator();
            while (it_neighbor.next()) |entry| {
                std.debug.print(" {s}:{d}", .{
                    self.strtab.get_str(entry.key_ptr.*) orelse "***",
                    entry.value_ptr.*,
                });
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn getBestFullRoute(self: *Graph) !usize {
        var it = self.nodes.keyIterator();
        while (it.next()) |node| {
            try self.findBestWalk(node.*, 0);
        }
        return self.best;
    }

    fn findBestWalk(self: *Graph, src: StringId, dist: usize) !void {
        try self.visited.put(src, {});
        defer _ = self.visited.remove(src);

        if (self.visited.count() == self.nodes.count()) {
            const improved = if (self.shortest) self.best > dist else self.best < dist;
            if (improved) {
                self.best = dist;
            }
            return;
        }

        const node_maybe = self.nodes.get(src);
        if (node_maybe) |node| {
            var it = node.neighbors.iterator();
            while (it.next()) |neighbor| {
                const tgt = neighbor.key_ptr.*;
                if (self.visited.contains(tgt)) continue;
                try self.findBestWalk(tgt, dist + neighbor.value_ptr.*);
            }
        } else {
            return error.InvalidNode;
        }
    }

    fn addNode(self: *Graph, name: StringId) !*Node {
        const r = try self.nodes.getOrPut(name);
        if (!r.found_existing) {
            r.value_ptr.* = Node.init(self.allocator, name);
        }
        return r.value_ptr;
    }

    fn addRoute(self: *Graph, src: StringId, tgt: StringId, dist: usize) !void {
        const s = try self.addNode(src);
        const rs = try s.*.neighbors.getOrPut(tgt);
        rs.value_ptr.* = dist;

        const t = try self.addNode(tgt);
        const rt = try t.*.neighbors.getOrPut(src);
        rt.value_ptr.* = dist;
    }
};

test "sample part 1" {
    const data =
        \\London to Dublin = 464
        \\London to Belfast = 518
        \\Dublin to Belfast = 141
    ;

    var graph = Graph.init(std.testing.allocator, true);
    defer graph.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try graph.addLine(line);
    }
    // graph.show();

    const best = try graph.getBestFullRoute();
    const expected = @as(usize, 605);
    try testing.expectEqual(expected, best);
}

test "sample part 2" {
    const data =
        \\London to Dublin = 464
        \\London to Belfast = 518
        \\Dublin to Belfast = 141
    ;

    var graph = Graph.init(std.testing.allocator, false);
    defer graph.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try graph.addLine(line);
    }
    // graph.show();

    const best = try graph.getBestFullRoute();
    const expected = @as(usize, 982);
    try testing.expectEqual(expected, best);
}
