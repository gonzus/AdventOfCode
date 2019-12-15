const std = @import("std");
const assert = std.debug.assert;
const Computer = @import("./computer.zig").Computer;

pub const Pos = struct {
    x: usize,
    y: usize,

    pub fn init(x: usize, y: usize) Pos {
        return Pos{
            .x = x,
            .y = y,
        };
    }

    pub fn encode(self: Pos) usize {
        return self.x * 10000 + self.y;
    }

    pub fn decode(self: *Pos, encoded: usize) void {
        self.y = encoded % 10000;
        self.x = encoded / 10000;
    }
};

pub const Map = struct {
    cells: std.AutoHashMap(usize, Tile),
    computer: Computer,
    pcur: Pos,
    ptgt: Pos,
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
            .pcur = Pos{ .x = 1000, .y = 1000 },
            .ptgt = undefined,
            .pmin = Pos{ .x = 999999, .y = 999999 },
            .pmax = Pos{ .x = 0, .y = 0 },
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.computer.deinit();
        self.cells.deinit();
    }

    pub fn parse(self: *Map, str: []const u8) void {
        self.computer.parse(str);
    }

    pub fn set_pos(self: *Map, pos: Pos, mark: Tile) void {
        _ = self.cells.put(pos.encode(), mark) catch unreachable;
        if (self.pmin.x > pos.x) self.pmin.x = pos.x;
        if (self.pmin.y > pos.y) self.pmin.y = pos.y;
        if (self.pmax.x < pos.x) self.pmax.x = pos.x;
        if (self.pmax.y < pos.y) self.pmax.y = pos.y;
    }

    pub fn walk(self: *Map) void {
        self.mark_and_walk(Tile.Empty);
    }

    fn mark_and_walk(self: *Map, mark: Tile) void {
        self.set_pos(self.pcur, mark);
        // self.show();
        if (mark == Tile.Wall) return;

        const pold = self.pcur;
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
            self.pcur.x = @intCast(usize, @intCast(i32, pold.x) + dx);
            self.pcur.y = @intCast(usize, @intCast(i32, pold.y) + dy);
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
                    std.debug.warn("TARGET {} {}\n", self.pcur.x, self.pcur.y);
                    self.ptgt = self.pcur;
                    self.mark_and_walk(Tile.Empty);
                    _ = self.tryMove(r);
                },
            }
        }
        self.pcur = pold;
    }

    pub fn tryMove(self: *Map, d: Dir) Status {
        self.computer.enqueueInput(@enumToInt(d));
        self.computer.run();
        const output = self.computer.getOutput();
        if (output.? == 2) std.debug.warn("======= FUCK 2\n");
        const status = @intToEnum(Status, @intCast(u8, output.?));
        // std.debug.warn("TRY: {} {} - {} : {}\n", self.pcur.x, self.pcur.y, d, status);
        return status;
    }

    pub fn find_path_to_target(self: *Map) usize {
        //  1  function Dijkstra(Graph, source):
        var allocator = std.heap.direct_allocator;
        var Q = std.AutoHashMap(usize, void).init(allocator);
        var D = std.AutoHashMap(usize, usize).init(allocator);
        var P = std.AutoHashMap(usize, usize).init(allocator);

        var y: usize = self.pmin.y;
        while (y <= self.pmax.y) : (y += 1) {
            var x: usize = self.pmin.x;
            while (x <= self.pmax.x) : (x += 1) {
                const p = Pos.init(x, y);
                const v = p.encode();
                _ = D.put(v, std.math.maxInt(usize)) catch unreachable;
                _ = Q.put(v, {}) catch unreachable;
            }
        }
        const s = self.pcur.encode();
        const t = self.ptgt.encode();
        _ = D.put(s, 0) catch unreachable;
        while (Q.count() != 0) {
            var u: usize = undefined;
            var m: usize = std.math.maxInt(usize);
            var it = Q.iterator();
            while (it.next()) |v| {
                if (!D.contains(v.key)) {
                    continue;
                }
                const z = D.get(v.key).?;
                if (m > z.value) {
                    m = z.value;
                    u = z.key;
                }
            }
            std.debug.warn("MIN u {} {}\n", u, m);
            if (u == t) {
                break;
            }
            _ = Q.remove(u);
            const du = D.get(u).?.value;
            std.debug.warn("DIST u {} = {}\n", u, du);
            var j: u8 = 1;
            while (j <= 4) : (j += 1) {
                var dx: i32 = 0;
                var dy: i32 = 0;
                const d = @intToEnum(Dir, j);
                switch (d) {
                    Dir.N => {
                        dy = -1;
                    },
                    Dir.S => {
                        dy = 1;
                    },
                    Dir.W => {
                        dx = -1;
                    },
                    Dir.E => {
                        dx = 1;
                    },
                }
                var vpos: Pos = undefined;
                vpos.decode(u);
                vpos.x = @intCast(usize, @intCast(i32, vpos.x) + dx);
                vpos.y = @intCast(usize, @intCast(i32, vpos.y) + dy);
                const v = vpos.encode();
                std.debug.warn("NEIGHBOR v {} @ {} {}\n", v, vpos.x, vpos.y);
                if (!self.cells.contains(v)) continue;
                std.debug.warn("NEIGHBOR v FOUND\n");
                const tile = self.cells.get(v).?.value;
                if (tile == Tile.Wall) continue;
                std.debug.warn("NEIGHBOR v NOT WALL\n");
                const dv = D.get(v).?.value;
                const alt = du + 1;
                std.debug.warn("NEIGHBOR v {} = {}\n", v, alt);
                if (alt < dv) {
                    _ = D.put(v, alt) catch unreachable;
                    _ = P.put(v, u) catch unreachable;
                }
            }
        }

        var dist: usize = 0;
        var n = t;
        while (true) {
            if (n == s) break;
            n = P.get(n).?.value;
            dist += 1;
        }
        return dist;
    }

    fn lessThanFD(l: FillData, r: FillData) bool {
        return l.dist < r.dist;
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
    };

    pub fn fill_with_oxygen(self: *Map) usize {
        var allocator = std.heap.direct_allocator;

        var seen = std.AutoHashMap(usize, void).init(allocator);
        defer seen.deinit();

        const PQ = std.PriorityQueue(FillData);
        var Q = PQ.init(allocator, lessThanFD);
        defer Q.deinit();

        var md: usize = 0;
        _ = Q.add(FillData.init(self.ptgt, 0)) catch unreachable;
        while (Q.count() != 0) {
            const data = Q.remove();
            const u = data.pos.encode();
            _ = self.cells.put(u, Tile.Oxygen) catch unreachable;
            if (md < data.dist) md = data.dist;
            std.debug.warn("MD: {}\n", md);
            self.show();
            const dist = data.dist + 1;
            var j: u8 = 1;
            while (j <= 4) : (j += 1) {
                var dx: i32 = 0;
                var dy: i32 = 0;
                const d = @intToEnum(Dir, j);
                switch (d) {
                    Dir.N => {
                        dy = -1;
                    },
                    Dir.S => {
                        dy = 1;
                    },
                    Dir.W => {
                        dx = -1;
                    },
                    Dir.E => {
                        dx = 1;
                    },
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
                _ = Q.add(FillData.init(vpos, dist)) catch unreachable;
            }
        }
        return md;
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
    std.debug.warn("\n");
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
                map.ptgt = p;
            }
            map.set_pos(p, t);
        }
    }
    map.show();
    const result = map.fill_with_oxygen();
    std.debug.warn("Fill in {} minutes\n", result);
    assert(result == 4);
}
