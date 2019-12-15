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

    pub fn encode(self: Pos) usize {
        return self.x * OFFSET + self.y;
    }

    pub fn decode(self: *Pos, encoded: usize) void {
        self.y = encoded % OFFSET;
        self.x = encoded / OFFSET;
    }
};

pub const Map = struct {
    cells: std.AutoHashMap(usize, Tile),
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
            .cells = std.AutoHashMap(usize, Tile).init(std.heap.direct_allocator),
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
        _ = self.cells.put(pos.encode(), mark) catch unreachable;
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
            var dx: i32 = 0;
            var dy: i32 = 0;
            const d = @intToEnum(Dir, j);
            var r: Dir = undefined;
            switch (d) {
                Dir.N => {
                    dy = -1;
                    r = Dir.S;
                },
                Dir.S => {
                    dy = 1;
                    r = Dir.N;
                },
                Dir.W => {
                    dx = -1;
                    r = Dir.E;
                },
                Dir.E => {
                    dx = 1;
                    r = Dir.W;
                },
            }
            self.pcur.x = @intCast(usize, @intCast(i32, pcur.x) + dx);
            self.pcur.y = @intCast(usize, @intCast(i32, pcur.y) + dy);
            if (self.cells.contains(self.pcur.encode())) continue;

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

    // Long live the master, Edsger W. Dijkstra
    // https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm
    pub fn find_path_to_target(self: *Map) usize {
        var allocator = std.heap.direct_allocator;
        var Pend = std.AutoHashMap(usize, void).init(allocator);
        defer Pend.deinit();
        var Dist = std.AutoHashMap(usize, usize).init(allocator);
        defer Dist.deinit();
        var Path = std.AutoHashMap(usize, usize).init(allocator);
        defer Path.deinit();

        // Fill Dist and Pend for all nodes
        var y: usize = self.pmin.y;
        while (y <= self.pmax.y) : (y += 1) {
            var x: usize = self.pmin.x;
            while (x <= self.pmax.x) : (x += 1) {
                const p = Pos.init(x, y);
                const u = p.encode();
                _ = Dist.put(u, std.math.maxInt(usize)) catch unreachable;
                _ = Pend.put(u, {}) catch unreachable;
            }
        }
        const s = self.pcur.encode();
        const t = self.poxy.encode();
        _ = Dist.put(s, 0) catch unreachable;
        while (Pend.count() != 0) {
            // Search a pending node with minimal distance
            var u: usize = undefined;
            var dmin: usize = std.math.maxInt(usize);
            var it = Pend.iterator();
            while (it.next()) |v| {
                if (!Dist.contains(v.key)) {
                    continue;
                }
                const found = Dist.get(v.key).?;
                if (dmin > found.value) {
                    dmin = found.value;
                    u = found.key;
                }
            }
            _ = Pend.remove(u);
            if (u == t) {
                // node chosen is our target, we can stop searching now
                break;
            }

            // update dist for all neighbours of u
            // add closest neighbour of u to the path
            const du = Dist.get(u).?.value;
            var j: u8 = 1;
            while (j <= 4) : (j += 1) {
                var dx: i32 = 0;
                var dy: i32 = 0;
                const d = @intToEnum(Dir, j);
                switch (d) {
                    Dir.N => dy = -1,
                    Dir.S => dy = 1,
                    Dir.W => dx = -1,
                    Dir.E => dx = 1,
                }
                var vpos: Pos = undefined;
                vpos.decode(u);
                vpos.x = @intCast(usize, @intCast(i32, vpos.x) + dx);
                vpos.y = @intCast(usize, @intCast(i32, vpos.y) + dy);
                const v = vpos.encode();
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
        var n = t;
        while (true) {
            if (n == s) break;
            n = Path.get(n).?.value;
            dist += 1;
        }
        return dist;
    }

    const FillData = struct {
        pos: Pos,
        dist: usize,

        pub fn init(pos: Pos, dist: usize) FillData {
            return FillData{
                .pos = pos,
                .dist = dist,
            };
        }

        fn lessThan(l: FillData, r: FillData) bool {
            return l.dist < r.dist;
        }
    };

    // https://en.wikipedia.org/wiki/Flood_fill
    // Basically a BFS walk, remembering the distance to the source
    pub fn fill_with_oxygen(self: *Map) usize {
        var allocator = std.heap.direct_allocator;

        var seen = std.AutoHashMap(usize, void).init(allocator);
        defer seen.deinit();

        const PQ = std.PriorityQueue(FillData);
        var Pend = PQ.init(allocator, FillData.lessThan);
        defer Pend.deinit();

        // We start from the oxygen system position, which has already been filled with oxygen
        var dmax: usize = 0;
        _ = Pend.add(FillData.init(self.poxy, 0)) catch unreachable;
        while (Pend.count() != 0) {
            const data = Pend.remove();
            if (dmax < data.dist) dmax = data.dist;
            const u = data.pos.encode();
            _ = self.cells.put(u, Tile.Oxygen) catch unreachable;
            // std.debug.warn("MD: {}\n", dmax);
            // self.show();

            // any neighbours will be filled at the same larger distance
            const dist = data.dist + 1;
            var j: u8 = 1;
            while (j <= 4) : (j += 1) {
                var dx: i32 = 0;
                var dy: i32 = 0;
                const d = @intToEnum(Dir, j);
                switch (d) {
                    Dir.N => dy = -1,
                    Dir.S => dy = 1,
                    Dir.W => dx = -1,
                    Dir.E => dx = 1,
                }
                var vpos = data.pos;
                vpos.x = @intCast(usize, @intCast(i32, vpos.x) + dx);
                vpos.y = @intCast(usize, @intCast(i32, vpos.y) + dy);
                const v = vpos.encode();
                if (!self.cells.contains(v)) continue;
                const tile = self.cells.get(v).?.value;
                if (tile != Tile.Empty) continue;
                if (seen.contains(v)) continue;
                _ = seen.put(v, {}) catch unreachable;
                _ = Pend.add(FillData.init(vpos, dist)) catch unreachable;
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
                const g = self.cells.get(p.encode());
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
