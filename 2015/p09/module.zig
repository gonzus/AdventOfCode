const std = @import("std");
const testing = std.testing;
const DirectedGraph = @import("./util/graph.zig").DirectedGraph;

const Allocator = std.mem.Allocator;

pub const Map = struct {
    const Graph = DirectedGraph(usize);

    allocator: Allocator,
    graph: Graph,
    shortest: bool,
    best: usize,

    pub fn init(allocator: Allocator, shortest: bool) Map {
        const self = Map{
            .allocator = allocator,
            .graph = Graph.init(allocator),
            .shortest = shortest,
            .best = if (shortest) std.math.maxInt(usize) else std.math.minInt(usize),
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.graph.deinit();
    }

    pub fn addLine(self: *Map, line: []const u8) !void {
        var src: []const u8 = undefined;
        var tgt: []const u8 = undefined;
        var dist: usize = 0;

        var pos: usize = 0;
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        while (it.next()) |chunk| : (pos += 1) {
            switch (pos) {
                0 => src = chunk,
                2 => tgt = chunk,
                4 => dist = try std.fmt.parseUnsigned(usize, chunk, 10),
                else => continue,
            }
        }

        try self.graph.joinNodes(src, tgt, dist);
    }

    fn handle(context: anytype, dist: usize) void {
        var self: *Map = @ptrCast(context);
        const improved = if (self.shortest) self.best > dist else self.best < dist;
        if (improved) {
            self.best = dist;
        }
    }

    pub fn getBestFullRoute(self: *Map) !usize {
        self.graph.reset();
        var it = self.graph.nodes.keyIterator();
        while (it.next()) |node| {
            try self.graph.findBestWalk(node.*, 0, handle, self);
        }
        return self.best;
    }
};

test "sample part 1" {
    const data =
        \\London to Dublin = 464
        \\London to Belfast = 518
        \\Dublin to Belfast = 141
    ;

    var map = Map.init(std.testing.allocator, true);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }
    // map.graph.show();

    const best = try map.getBestFullRoute();
    const expected = @as(usize, 605);
    try testing.expectEqual(expected, best);
}

test "sample part 2" {
    const data =
        \\London to Dublin = 464
        \\London to Belfast = 518
        \\Dublin to Belfast = 141
    ;

    var map = Map.init(std.testing.allocator, false);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }
    // map.graph.show();

    const best = try map.getBestFullRoute();
    const expected = @as(usize, 982);
    try testing.expectEqual(expected, best);
}
