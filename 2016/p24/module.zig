const std = @import("std");
const testing = std.testing;
const Grid = @import("./util/grid.zig").Grid;
const Math = @import("./util/math.zig").Math;
const FloodFill = @import("./util/graph.zig").FloodFill;

const Allocator = std.mem.Allocator;

pub const Roof = struct {
    const INFINITY = std.math.maxInt(usize);
    const MAX_WIRES = 10;

    const Data = Grid(u8);
    const Pos = Math.Vector(usize, 2);

    allocator: Allocator,
    cycle: bool,
    grid: Data,
    wires: std.AutoHashMap(usize, Pos),

    pub fn init(allocator: Allocator, cycle: bool) Roof {
        return .{
            .allocator = allocator,
            .cycle = cycle,
            .grid = Data.init(allocator, '.'),
            .wires = std.AutoHashMap(usize, Pos).init(allocator),
        };
    }

    pub fn deinit(self: *Roof) void {
        self.wires.deinit();
        self.grid.deinit();
    }

    pub fn addLine(self: *Roof, line: []const u8) !void {
        try self.grid.ensureCols(line.len);
        try self.grid.ensureExtraRow();
        const y = self.grid.rows();
        for (line, 0..) |c, x| {
            try self.grid.set(x, y, c);
            if (!std.ascii.isDigit(c)) continue;
            const w: usize = c - '0';
            try self.wires.put(w, Pos.copy(&[_]usize{ x, y }));
        }
    }

    pub fn show(self: Roof) void {
        std.debug.print("Roof with grid {}x{} and {} wires\n", .{ self.grid.rows(), self.grid.cols(), self.wires.count() });
        var it = self.wires.iterator();
        while (it.next()) |e| {
            std.debug.print("Wire {} at {}\n", .{ e.key_ptr.*, e.value_ptr.* });
        }
        for (0..self.grid.rows()) |y| {
            for (0..self.grid.cols()) |x| {
                std.debug.print("{c}", .{self.grid.get(x, y)});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn findShortestPath(self: *Roof) !usize {
        var graph = Graph.init(self.cycle);

        try self.buildGraph(&graph);
        // graph.show();

        graph.runFloydWarshall();

        var wires: [MAX_WIRES]usize = undefined;
        for (0..MAX_WIRES) |w| {
            wires[w] = w;
        }
        const length = graph.exploreWires(wires[0..graph.size], 1);
        return length;
    }

    const FF = FloodFill(Context, Pos);
    const Context = struct {
        roof: *Roof,
        graph: *Graph,
        src: usize,
        nbuf: [10]Pos,
        nlen: usize,

        pub fn init(roof: *Roof, graph: *Graph) Context {
            return .{
                .roof = roof,
                .graph = graph,
                .src = undefined,
                .nbuf = undefined,
                .nlen = 0,
            };
        }

        pub fn visit(self: *Context, pos: Pos, dist: usize, seen: usize) !FF.Action {
            _ = seen;
            const c = self.roof.grid.get(pos.v[0], pos.v[1]);
            if (std.ascii.isDigit(c)) {
                const tgt: usize = c - '0';
                if (tgt != self.src) {
                    self.graph.addEdge(self.src, tgt, dist);
                    return .skip;
                }
            }
            return .visit;
        }

        pub fn neighbors(self: *Context, pos: Pos) []Pos {
            self.nlen = 0;
            const dxs = [_]isize{ 1, -1, 0, 0 };
            const dys = [_]isize{ 0, 0, 1, -1 };
            for (dxs, dys) |dx, dy| {
                var ix: isize = @intCast(pos.v[0]);
                ix += dx;
                if (ix < 0) continue;
                const nx: usize = @intCast(ix);
                if (nx >= self.roof.grid.cols()) continue;

                var iy: isize = @intCast(pos.v[1]);
                iy += dy;
                if (iy < 0) continue;
                const ny: usize = @intCast(iy);
                if (ny >= self.roof.grid.rows()) continue;

                const c = self.roof.grid.get(nx, ny);
                if (c == '#') continue;

                self.nbuf[self.nlen] = Pos.copy(&[_]usize{ nx, ny });
                self.nlen += 1;
            }
            return self.nbuf[0..self.nlen];
        }
    };

    fn buildGraph(self: *Roof, graph: *Graph) !void {
        var context = Context.init(self, graph);
        var ff = FF.init(self.allocator, &context);
        defer ff.deinit();

        var it = self.wires.iterator();
        while (it.next()) |entry| {
            context.src = entry.key_ptr.*;
            try ff.run(entry.value_ptr.*);
        }
    }

    const Graph = struct {
        cycle: bool,
        size: usize,
        dist: [MAX_WIRES][MAX_WIRES]usize,

        pub fn init(cycle: bool) Graph {
            var self = Graph{
                .cycle = cycle,
                .size = 0,
                .dist = undefined,
            };
            for (0..MAX_WIRES) |s| {
                for (0..MAX_WIRES) |t| {
                    self.dist[s][t] = INFINITY;
                }
            }
            return self;
        }

        pub fn addEdge(self: *Graph, src: usize, tgt: usize, dist: usize) void {
            if (self.size <= src) self.size = src + 1;
            if (self.size <= tgt) self.size = tgt + 1;

            self.dist[src][src] = 0;
            self.dist[tgt][tgt] = 0;
            self.dist[src][tgt] = dist;
            self.dist[tgt][src] = dist;
        }

        pub fn show(self: Graph) void {
            std.debug.print("Graph with {} nodes\n", .{self.size});
            for (0..self.size) |s| {
                std.debug.print("Node {}: ", .{s});
                for (0..self.size) |t| {
                    const d = self.dist[s][t];
                    if (d == INFINITY) continue;
                    if (d == 0) continue;
                    std.debug.print(" {}={}", .{ t, d });
                }
                std.debug.print("\n", .{});
            }
        }

        pub fn runFloydWarshall(self: *Graph) void {
            // We reuse the dist array -- before it was the edge distance
            // between adjacent nodes, now it will be the shortest distance
            // between each pair of nodes.
            for (0..self.size) |k| {
                for (0..self.size) |i| {
                    for (0..self.size) |j| {
                        if (self.dist[i][k] == INFINITY) continue;
                        if (self.dist[k][j] == INFINITY) continue;
                        const d = self.dist[i][k] + self.dist[k][j];
                        if (self.dist[i][j] <= d) continue;
                        self.dist[i][j] = d;
                    }
                }
            }
        }

        pub fn exploreWires(self: Graph, wires: []usize, l: usize) usize {
            if (l == wires.len) {
                var length: usize = 0;
                for (1..wires.len) |p| {
                    length += self.dist[wires[p - 1]][wires[p]];
                }
                if (self.cycle) {
                    length += self.dist[wires[wires.len - 1]][0];
                }
                return length;
            }

            var best: usize = std.math.maxInt(usize);
            for (l..wires.len) |j| {
                std.mem.swap(usize, &wires[l], &wires[j]);
                const length = self.exploreWires(wires, l + 1);
                if (best > length) best = length;
                std.mem.swap(usize, &wires[l], &wires[j]);
            }
            return best;
        }
    };
};

test "sample part 1" {
    const data =
        \\###########
        \\#0.1.....2#
        \\#.#######.#
        \\#4.......3#
        \\###########
    ;

    var roof = Roof.init(std.testing.allocator, false);
    defer roof.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try roof.addLine(line);
    }
    // roof.show();

    const length = try roof.findShortestPath();
    const expected = @as(usize, 14);
    try testing.expectEqual(expected, length);
}
