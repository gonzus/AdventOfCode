const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Cluster = struct {
    const Pos = Math.Vector(usize, 2);
    const INFINITY = std.math.maxInt(usize);

    const Node = struct {
        pos: Pos,
        size: usize,
        used: usize,

        pub fn init(x: usize, y: usize, size: usize, used: usize) Node {
            return .{
                .pos = Pos.copy(&[_]usize{ x, y }),
                .size = size,
                .used = used,
            };
        }

        pub fn fitsSize(self: Node, size: usize) bool {
            return self.size - self.used >= size;
        }

        pub fn isEmpty(self: Node) bool {
            return self.used == 0;
        }

        pub fn isMostlyFull(self: Node) bool {
            const u = 100 * self.used / self.size;
            return u >= 85;
        }

        pub fn isLarge(self: Node, ave: usize) bool {
            return self.size > ave * 2;
        }

        pub fn isLargeAndMostlyFull(self: Node, ave: usize) bool {
            if (!self.isLarge(ave)) return false;
            if (!self.isMostlyFull()) return false;
            return true;
        }
    };

    allocator: Allocator,
    nodes: std.AutoHashMap(Pos, Node),
    total: usize,
    maxx: usize,
    maxy: usize,

    pub fn init(allocator: Allocator) Cluster {
        return .{
            .allocator = allocator,
            .nodes = std.AutoHashMap(Pos, Node).init(allocator),
            .total = 0,
            .maxx = 0,
            .maxy = 0,
        };
    }

    pub fn deinit(self: *Cluster) void {
        self.nodes.deinit();
    }

    pub fn addLine(self: *Cluster, line: []const u8) !void {
        if (line[0] != '/') return;
        var it = std.mem.tokenizeAny(u8, line, "/- ");
        _ = it.next();
        _ = it.next();
        _ = it.next();
        const x_str = it.next().?;
        const x = try std.fmt.parseUnsigned(usize, x_str[1..], 10);
        const y_str = it.next().?;
        const y = try std.fmt.parseUnsigned(usize, y_str[1..], 10);
        const s_str = it.next().?;
        const s = try std.fmt.parseUnsigned(usize, s_str[0 .. s_str.len - 1], 10);
        const u_str = it.next().?;
        const u = try std.fmt.parseUnsigned(usize, u_str[0 .. u_str.len - 1], 10);
        const node = Node.init(x, y, s, u);
        try self.nodes.put(node.pos, node);
        self.total += s;
        if (self.maxy < y) self.maxy = y;
        if (self.maxx < x) self.maxx = x;
    }

    pub fn show(self: Cluster) void {
        const goal = Pos.copy(&[_]usize{ self.maxx, 0 });
        const ave = self.total / self.nodes.count();
        for (0..self.maxy + 1) |y| {
            for (0..self.maxx + 1) |x| {
                const p = Pos.copy(&[_]usize{ x, y });
                var c: u8 = '.';
                if (p.equal(goal)) {
                    c = 'G';
                } else {
                    const n_opt = self.nodes.get(p);
                    if (n_opt) |n| {
                        if (n.isEmpty()) {
                            c = '_';
                        } else if (n.isLargeAndMostlyFull(ave)) {
                            c = '#';
                        }
                    }
                }
                std.debug.print("{c}", .{c});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn getViableNodes(self: Cluster) !usize {
        var count: usize = 0;
        var it0 = self.nodes.valueIterator();
        while (it0.next()) |A| {
            if (A.used == 0) continue;
            var it1 = self.nodes.valueIterator();
            while (it1.next()) |B| {
                if (A.pos.equal(B.pos)) continue;
                if (!B.fitsSize(A.used)) continue;
                count += 1;
            }
        }
        return count;
    }

    pub fn getMovesNeeded(self: Cluster) !usize {
        const goal = Pos.copy(&[_]usize{ self.maxx, 0 });
        var spacious: ?Pos = null;
        for (0..self.maxy + 1) |y| {
            for (0..self.maxx + 1) |x| {
                const p = Pos.copy(&[_]usize{ x, y });
                const n_opt = self.nodes.get(p);
                if (n_opt) |n| {
                    if (n.isEmpty()) {
                        spacious = p;
                    }
                }
            }
        }
        if (spacious) |s| return self.search(s, goal);
        return 0;
    }

    const State = struct {
        tmp: Pos, // node with temporary available space
        tgt: Pos, // node where we want to make space

        pub fn init(tmp: Pos, tgt: Pos) State {
            return .{ .tmp = tmp, .tgt = tgt };
        }

        pub fn heuristic(self: State, wanted: Pos) usize {
            return Pos.manhattanDist(self.tmp, self.tgt) + Pos.manhattanDist(self.tgt, wanted);
        }
    };

    const StateDist = struct {
        state: State,
        dist: usize,

        pub fn init(state: State, dist: usize) StateDist {
            return .{ .state = state, .dist = dist };
        }

        fn lessThan(_: void, l: StateDist, r: StateDist) std.math.Order {
            const od = std.math.order(l.dist, r.dist);
            if (od != .eq) return od;
            const os = Pos.cmp({}, l.state.tmp, r.state.tmp);
            if (os != .eq) return os;
            const ot = Pos.cmp({}, l.state.tgt, r.state.tgt);
            return ot;
        }
    };

    const PQ = std.PriorityQueue(StateDist, void, StateDist.lessThan);

    fn search(self: Cluster, tmp: Pos, tgt: Pos) !usize {
        var closed = std.AutoHashMap(State, void).init(self.allocator);
        defer closed.deinit();
        var best = std.AutoHashMap(State, usize).init(self.allocator);
        defer best.deinit();
        var queue = PQ.init(self.allocator, {});
        defer queue.deinit();

        const wanted = Pos.copy(&[_]usize{ 0, 0 });
        const ave = self.total / self.nodes.count();
        const start = State.init(tmp, tgt);
        try best.put(start, 0);
        try queue.add(StateDist.init(start, start.heuristic(wanted)));
        while (queue.count() > 0) {
            const elem = queue.remove();
            const curr = elem.state;
            if (curr.tgt.equal(wanted)) {
                return best.get(curr).?;
            }
            try closed.put(curr, {});
            const deltax = [_]isize{ -1, 1, 0, 0 };
            const deltay = [_]isize{ 0, 0, -1, 1 };
            for (deltax, deltay) |dx, dy| {
                var ix: isize = @intCast(curr.tmp.v[0]);
                ix += dx;
                if (ix < 0) continue;
                const nx: usize = @intCast(ix);
                if (nx > self.maxx) continue;

                var iy: isize = @intCast(curr.tmp.v[1]);
                iy += dy;
                if (iy < 0) continue;
                const ny: usize = @intCast(iy);
                if (ny > self.maxy) continue;

                const v = Pos.copy(&[_]usize{ nx, ny });
                var next = State.init(v, curr.tgt);
                if (v.equal(curr.tgt)) {
                    // alternate between tgt and tmp
                    next.tgt = curr.tmp;
                }
                if (closed.contains(next)) continue;

                const n_opt = self.nodes.get(v);
                if (n_opt) |n| {
                    if (n.isLargeAndMostlyFull(ave)) continue;
                }

                var curr_dist: usize = INFINITY;
                const curr_opt = best.get(curr);
                if (curr_opt) |dist| {
                    curr_dist = dist;
                }
                var next_dist: usize = INFINITY;
                const next_opt = best.get(next);
                if (next_opt) |dist| {
                    next_dist = dist;
                }
                const next_cost = curr_dist + 1;
                if (next_cost >= next_dist) continue;

                try best.put(next, next_cost);
                try queue.add(StateDist.init(next, next_cost + next.heuristic(wanted)));
            }
        }
        return 0;
    }
};

test "sample part 2" {
    const data =
        \\Filesystem            Size  Used  Avail  Use%
        \\/dev/grid/node-x0-y0   10T    8T     2T   80%
        \\/dev/grid/node-x0-y1   11T    6T     5T   54%
        \\/dev/grid/node-x0-y2   32T   28T     4T   87%
        \\/dev/grid/node-x1-y0    9T    7T     2T   77%
        \\/dev/grid/node-x1-y1    8T    0T     8T    0%
        \\/dev/grid/node-x1-y2   11T    7T     4T   63%
        \\/dev/grid/node-x2-y0   10T    6T     4T   60%
        \\/dev/grid/node-x2-y1    9T    8T     1T   88%
        \\/dev/grid/node-x2-y2    9T    6T     3T   66%
    ;

    var cluster = Cluster.init(std.testing.allocator);
    defer cluster.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    const moves = try cluster.getMovesNeeded();
    const expected = @as(usize, 7);
    try testing.expectEqual(expected, moves);
}
