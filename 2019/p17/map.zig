const std = @import("std");
const assert = std.debug.assert;
const Computer = @import("./computer.zig").Computer;

pub const Pos = struct {
    const OFFSET: usize = 10000;

    x: usize,
    y: usize,

    pub fn init(x: usize, y: usize) Pos {
        return Pos{
            .x = x,
            .y = y,
        };
    }

    pub fn equal(self: Pos, other: Pos) bool {
        return self.x == other.x and self.y == other.y;
    }
};

pub const Map = struct {
    cells: std.AutoHashMap(Pos, Tile),
    computer: Computer,
    pcur: Pos,
    poxy: Pos,
    pmin: Pos,
    pmax: Pos,

    pub const Dir = enum(u8) {
        N = 1,
        S = 2,
        W = 3,
        E = 4,

        pub fn reverse(d: Dir) Dir {
            return switch (d) {
                Dir.N => Dir.S,
                Dir.S => Dir.N,
                Dir.W => Dir.E,
                Dir.E => Dir.W,
            };
        }

        pub fn move(p: Pos, d: Dir) Pos {
            var q = p;
            switch (d) {
                Dir.N => q.y -= 1,
                Dir.S => q.y += 1,
                Dir.W => q.x -= 1,
                Dir.E => q.x += 1,
            }
            return q;
        }
    };

    pub const Status = enum(u8) {
        HitWall = 0,
        Moved = 1,
        MovedToTarget = 2,
    };

    pub const Tile = enum(u8) {
        Empty = 0,
        Wall = 1,
        Oxygen = 2,
    };

    pub fn init() Map {
        var self = Map{
            .cells = std.AutoHashMap(Pos, Tile).init(std.heap.direct_allocator),
            .computer = Computer.init(true),
            .poxy = undefined,
            .pcur = Pos.init(Pos.OFFSET / 2, Pos.OFFSET / 2),
            .pmin = Pos.init(std.math.maxInt(usize), std.math.maxInt(usize)),
            .pmax = Pos.init(0, 0),
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.computer.deinit();
        self.cells.deinit();
    }

    pub fn parse_program(self: *Map, str: []const u8) void {
        self.computer.parse(str);
    }

    pub fn set_pos(self: *Map, pos: Pos, mark: Tile) void {
        _ = self.cells.put(pos, mark) catch unreachable;
        if (self.pmin.x > pos.x) self.pmin.x = pos.x;
        if (self.pmin.y > pos.y) self.pmin.y = pos.y;
        if (self.pmax.x < pos.x) self.pmax.x = pos.x;
        if (self.pmax.y < pos.y) self.pmax.y = pos.y;
    }

    pub fn walk_around(self: *Map) void {
        std.debug.warn("START droid at {} {}\n", self.pcur.x, self.pcur.y);
        self.mark_and_walk(Tile.Empty);
    }

    fn mark_and_walk(self: *Map, mark: Tile) void {
        self.set_pos(self.pcur, mark);
        // self.show();
        if (mark != Tile.Empty) return;

        const pcur = self.pcur;
        var j: u8 = 1;
        while (j <= 4) : (j += 1) {
            const d = @intToEnum(Dir, j);
            const r = Dir.reverse(d);
            self.pcur = Dir.move(pcur, d);
            if (self.cells.contains(self.pcur)) continue;

            const status = self.tryMove(d);
            switch (status) {
                Status.HitWall => {
                    // std.debug.warn("WALL {} {}\n", self.pcur.x, self.pcur.y);
                    self.mark_and_walk(Tile.Wall);
                },
                Status.Moved => {
                    // std.debug.warn("EMPTY {} {}\n", self.pcur.x, self.pcur.y);
                    self.mark_and_walk(Tile.Empty);
                    _ = self.tryMove(r);
                },
                Status.MovedToTarget => {
                    std.debug.warn("FOUND oxygen system at {} {}\n", self.pcur.x, self.pcur.y);
                    self.mark_and_walk(Tile.Empty);
                    self.poxy = self.pcur;
                    _ = self.tryMove(r);
                },
            }
        }
        self.pcur = pcur;
    }

    pub fn tryMove(self: *Map, d: Dir) Status {
        self.computer.enqueueInput(@enumToInt(d));
        self.computer.run();
        const output = self.computer.getOutput();
        const status = @intToEnum(Status, @intCast(u8, output.?));
        return status;
    }

    const PosDist = struct {
        pos: Pos,
        dist: usize,

        pub fn init(pos: Pos, dist: usize) PosDist {
            return PosDist{
                .pos = pos,
                .dist = dist,
            };
        }

        fn lessThan(l: PosDist, r: PosDist) bool {
            if (l.dist < r.dist) return true;
            if (l.dist > r.dist) return false;
            if (l.pos.x < r.pos.x) return true;
            if (l.pos.x > r.pos.x) return false;
            if (l.pos.y < r.pos.y) return true;
            if (l.pos.y > r.pos.y) return false;
            return false;
        }
    };

    // Long live the master, Edsger W. Dijkstra
    // https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm
    pub fn find_path_to_target(self: *Map) usize {
        var allocator = std.heap.direct_allocator;
        var Pend = std.AutoHashMap(Pos, void).init(allocator);
        defer Pend.deinit();
        var Dist = std.AutoHashMap(Pos, usize).init(allocator);
        defer Dist.deinit();
        var Path = std.AutoHashMap(Pos, Pos).init(allocator);
        defer Path.deinit();

        // Fill Dist and Pend for all nodes
        var y: usize = self.pmin.y;
        while (y <= self.pmax.y) : (y += 1) {
            var x: usize = self.pmin.x;
            while (x <= self.pmax.x) : (x += 1) {
                const p = Pos.init(x, y);
                _ = Dist.put(p, std.math.maxInt(usize)) catch unreachable;
                _ = Pend.put(p, {}) catch unreachable;
            }
        }
        _ = Dist.put(self.pcur, 0) catch unreachable;
        while (Pend.count() != 0) {
            // Search for a pending node with minimal distance
            // TODO: we could use a PriorityQueue here to quickly get at the
            // node, but we will also need to update the node's distance later,
            // which would mean re-shuffling the PQ; not sure how to do this.
            var u: Pos = undefined;
            var dmin: usize = std.math.maxInt(usize);
            var it = Pend.iterator();
            while (it.next()) |v| {
                const p = v.key;
                if (!Dist.contains(p)) {
                    continue;
                }
                const found = Dist.get(p).?;
                if (dmin > found.value) {
                    dmin = found.value;
                    u = found.key;
                }
            }
            _ = Pend.remove(u);
            if (u.equal(self.poxy)) {
                // node chosen is our target, we can stop searching now
                break;
            }

            // update dist for all neighbours of u
            // add closest neighbour of u to the path
            const du = Dist.get(u).?.value;
            var j: u8 = 1;
            while (j <= 4) : (j += 1) {
                const d = @intToEnum(Dir, j);
                var v = Dir.move(u, d);
                if (!self.cells.contains(v)) continue;
                const tile = self.cells.get(v).?.value;
                if (tile != Tile.Empty) continue;
                const dv = Dist.get(v).?.value;
                const alt = du + 1;
                if (alt < dv) {
                    _ = Dist.put(v, alt) catch unreachable;
                    _ = Path.put(v, u) catch unreachable;
                }
            }
        }

        // now count the steps in the path from target to source
        var dist: usize = 0;
        var n = self.poxy;
        while (true) {
            if (n.equal(self.pcur)) break;
            n = Path.get(n).?.value;
            dist += 1;
        }
        return dist;
    }

    // https://en.wikipedia.org/wiki/Flood_fill
    // Basically a BFS walk, remembering the distance to the source
    pub fn fill_with_oxygen(self: *Map) usize {
        var allocator = std.heap.direct_allocator;

        var seen = std.AutoHashMap(Pos, void).init(allocator);
        defer seen.deinit();

        const PQ = std.PriorityQueue(PosDist);
        var Pend = PQ.init(allocator, PosDist.lessThan);
        defer Pend.deinit();

        // We start from the oxygen system position, which has already been filled with oxygen
        var dmax: usize = 0;
        _ = Pend.add(PosDist.init(self.poxy, 0)) catch unreachable;
        while (Pend.count() != 0) {
            const data = Pend.remove();
            if (dmax < data.dist) dmax = data.dist;
            _ = self.cells.put(data.pos, Tile.Oxygen) catch unreachable;
            // std.debug.warn("MD: {}\n", dmax);
            // self.show();

            // any neighbours will be filled at the same larger distance
            const dist = data.dist + 1;
            var j: u8 = 1;
            while (j <= 4) : (j += 1) {
                const d = @intToEnum(Dir, j);
                var v = Dir.move(data.pos, d);
                if (!self.cells.contains(v)) continue;
                const tile = self.cells.get(v).?.value;
                if (tile != Tile.Empty) continue;
                if (seen.contains(v)) continue;
                _ = seen.put(v, {}) catch unreachable;
                _ = Pend.add(PosDist.init(v, dist)) catch unreachable;
            }
        }
        return dmax;
    }

    pub fn show(self: Map) void {
        const sx = self.pmax.x - self.pmin.x + 1;
        const sy = self.pmax.y - self.pmin.y + 1;
        std.debug.warn("MAP: {} x {} - {} {} - {} {}\n", sx, sy, self.pmin.x, self.pmin.y, self.pmax.x, self.pmax.y);
        var y: usize = self.pmin.y;
        while (y <= self.pmax.y) : (y += 1) {
            std.debug.warn("{:4} | ", y);
            var x: usize = self.pmin.x;
            while (x <= self.pmax.x) : (x += 1) {
                const p = Pos.init(x, y);
                const g = self.cells.get(p);
                var t: u8 = ' ';
                if (g != null) {
                    switch (g.?.value) {
                        Tile.Empty => t = '.',
                        Tile.Wall => t = '#',
                        Tile.Oxygen => t = 'O',
                    }
                }
                if (x == self.pcur.x and y == self.pcur.y) t = 'D';
                std.debug.warn("{c}", t);
            }
            std.debug.warn("\n");
        }
    }
};

test "foo" {
    var map = Map.init();
    defer map.deinit();

    const data =
        \\ ##
        \\#..##
        \\#.#..#
        \\#.O.#
        \\ ###
    ;
    var y: usize = 0;
    var itl = std.mem.separate(data, "\n");
    while (itl.next()) |line| : (y += 1) {
        var x: usize = 0;
        while (x < line.len) : (x += 1) {
            const p = Pos.init(x, y);
            var t: Map.Tile = Map.Tile.Empty;
            if (line[x] == '#') t = Map.Tile.Wall;
            if (line[x] == 'O') {
                t = Map.Tile.Oxygen;
                map.poxy = p;
            }
            map.set_pos(p, t);
        }
    }
    const result = map.fill_with_oxygen();
    assert(result == 4);
}

test "bar" {
    for (@typeInfo(Map.Dir).Enum.fields) |field| {
        std.debug.warn("{} {}\n", field.name, field.value);
    }
}
