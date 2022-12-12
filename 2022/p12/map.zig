const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Pos = struct {
    x: usize,
    y: usize,

    pub fn init(x: usize, y: usize) Pos {
        var self = Pos{.x = x, .y = y};
        return self;
    }

    pub fn move(self: Pos, dx: i32, dy: i32, maxx: usize, maxy: usize) ?Pos {
        const vx: i32 = @intCast(i32, self.x) + dx;
        if (vx < 0 or vx >= maxx) return null;
        const vy: i32 = @intCast(i32, self.y) + dy;
        if (vy < 0 or vy >= maxy) return null;
        return Pos.init(@intCast(usize, vx), @intCast(usize, vy));
    }
};

pub const Map = struct {
    const INFINITY = std.math.maxInt(u32);

    allocator: Allocator,
    heights: std.AutoHashMap(Pos, u8),
    rows: usize,
    cols: usize,
    start: Pos,
    end: Pos,

    pub fn init(allocator: Allocator) Map {
        var self = Map{
            .allocator = allocator,
            .heights = std.AutoHashMap(Pos, u8).init(allocator),
            .rows = 0,
            .cols = 0,
            .start = undefined,
            .end = undefined,
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.heights.deinit();
    }

    pub fn add_line(self: *Map, line: []const u8) !void {
        const y = self.rows;
        self.rows += 1;
        if (self.cols == 0) self.cols = line.len;
        if (self.cols != line.len) unreachable;
        for (line) |c, x| {
            const pos = Pos.init(x, y);
            var h: u8 = undefined;
            switch (c) {
                'S' => {
                    h = 'a';
                    self.start = pos;
                },
                'E' => {
                    h = 'z';
                    self.end = pos;
                },
                'a'...'z' => h = c,
                else => unreachable,
            }
            try self.heights.put(pos, h);
        }
    }

    pub fn show(self: Map) void {
        var y: usize = 0;
        while (y < self.rows) : (y += 1) {
            var x: usize = 0;
            while (x < self.cols) : (x += 1) {
                const pos = Pos.init(x, y);
                var h = self.heights.get(pos) orelse '.';
                if (std.meta.eql(pos, self.start)) h = 'S';
                if (std.meta.eql(pos, self.end)) h = 'E';
                std.debug.print("{c}", .{h});
            }
            std.debug.print("\n", .{});
        }
    }

    const Delta = struct {
        dx: i32,
        dy: i32,
    };
    const deltas = [4]Delta{
        .{.dx = -1, .dy =  0},
        .{.dx =  1, .dy =  0},
        .{.dx =  0, .dy = -1},
        .{.dx =  0, .dy =  1},
    };

    fn dijkstra(self: *Map, src: Pos, tgt: Pos) !usize {
        var distance = std.AutoHashMap(Pos, u32).init(self.allocator); // total distance so far to reach a node
        defer distance.deinit();
        var visited = Seen.init(self.allocator); // nodes we have already visited
        defer visited.deinit();
        var pending = std.PriorityQueue(NodeDist, void, NodeDist.lessThan).init(self.allocator, {}); // pending nodes to visit
        defer pending.deinit();
        var path = Path.init(src, self.allocator); // reverse path from a node to the source
        defer path.deinit();

        try pending.add(NodeDist.init(src, 0));
        while (pending.count() != 0) {
            const nd = pending.remove();
            const u_pos = nd.node;
            // std.debug.print("Considering node {}, so far distance={}\n", .{ u_id, nd.dist });
            if (std.meta.eql(u_pos, tgt)) break; // found target!
            _ = try visited.containsMaybeAdd(u_pos);

            const uh = self.heights.get(u_pos) orelse unreachable;
            const du = nd.dist;
            for (deltas) |delta| {
                const new = u_pos.move(delta.dx, delta.dy, self.cols, self.rows);
                if (new == null) continue;

                const v_pos = new.?;
                if (visited.contains(v_pos)) continue;

                const vh = self.heights.get(v_pos) orelse unreachable;
                if (vh > uh + 1) continue;

                const dist_uv = 1;
                const tentative = du + dist_uv;
                var dv: u32 = INFINITY;
                if (distance.get(v_pos)) |d| {
                    dv = d;
                }
                if (tentative >= dv) continue;

                try distance.put(v_pos, tentative);
                // in theory we should update the distance for v in pending, but this is O(n), so we simply add a new element which will have the updated (lower) distance
                // try pending.update(NodeDist.init(v_id, dv), NodeDist.init(v_id, tentative));
                try pending.add(NodeDist.init(v_pos, tentative));
                try path.addSegment(u_pos, v_pos, dist_uv);
            }
        }

        const cost = try path.totalCost(tgt);
        return cost;
    }

    pub fn find_route(self: *Map) !usize {
        return try self.dijkstra(self.start, self.end);
    }

    pub fn find_best_route(self: *Map) !usize {
        var best: usize = INFINITY;
        var y: usize = 0;
        while (y < self.rows) : (y += 1) {
            var x: usize = 0;
            while (x < self.cols) : (x += 1) {
                const pos = Pos.init(x, y);
                var h = self.heights.get(pos) orelse '.';
                if (h != 'a') continue;
                const length = try self.dijkstra(pos, self.end);
                if (length <= 0) continue;
                if (best > length) best = length;
            }
        }
        return best;
    }

    const Seen = struct {
        hash: std.AutoHashMap(Pos, void),

        pub fn init(allocator: std.mem.Allocator) Seen {
            var self = Seen{
                .hash = std.AutoHashMap(Pos, void).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Seen) void {
            self.hash.deinit();
        }

        pub fn contains(self: Seen, pos: Pos) bool {
            return self.hash.contains(pos);
        }

        pub fn containsMaybeAdd(self: *Seen, pos: Pos) !bool {
            const result = try self.hash.getOrPut(pos);
            return result.found_existing;
        }
    };

    const NodeDist = struct {
        node: Pos,
        dist: u32,

        pub fn init(node: Pos, dist: u32) NodeDist {
            return NodeDist{ .node = node, .dist = dist };
        }

        fn lessThan(context: void, l: NodeDist, r: NodeDist) std.math.Order {
            _ = context;
            return std.math.order(l.dist, r.dist);
        }
    };

    const Path = struct {
        src: Pos,
        path: std.AutoHashMap(Pos, NodeDist),

        pub fn init(src: Pos, allocator: std.mem.Allocator) Path {
            var self = Path{
                .src = src,
                .path = std.AutoHashMap(Pos, NodeDist).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Path) void {
            self.path.deinit();
        }

        pub fn clear(self: *Path) void {
            self.path.clearRetainingCapacity();
        }

        pub fn addSegment(self: *Path, src: Pos, tgt: Pos, dist: u32) !void {
            try self.path.put(tgt, NodeDist.init(src, dist));
        }

        pub fn totalCost(self: Path, tgt: Pos) !usize {
            var total_cost: usize = 0;
            var current = tgt;
            while (!std.meta.eql(current, self.src)) {
                if (self.path.getEntry(current)) |e| {
                    const whence = e.value_ptr.*;
                    const node = whence.node;
                    const dist = whence.dist;
                    current = node;
                    total_cost += dist;
                } else {
                    break;
                }
            }
            return total_cost;
        }
    };
};

test "sample part 1" {
    const data: []const u8 =
        \\Sabqponm
        \\abcryxxl
        \\accszExk
        \\acctuvwj
        \\abdefghi
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.add_line(line);
    }

    // map.show();

    var length = try map.find_route();
    try testing.expectEqual(@as(usize, 31), length);
}

test "sample part 2" {
    const data: []const u8 =
        \\Sabqponm
        \\abcryxxl
        \\accszExk
        \\acctuvwj
        \\abdefghi
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.add_line(line);
    }

    // map.show();

    var length = try map.find_best_route();
    try testing.expectEqual(@as(usize, 29), length);
}
