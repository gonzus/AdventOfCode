const std = @import("std");
const assert = std.debug.assert;

pub const Map = struct {
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

        fn lessThan(l: Pos, r: Pos) bool {
            if (l.x < r.x) return true;
            if (l.x > r.x) return false;
            if (l.y < r.y) return true;
            if (l.y > r.y) return false;
            return false;
        }
    };

    pub const Node = struct {
        p: Pos,
        m: usize,
        n: std.AutoHashMap(u64, void),

        pub fn init(p: Pos, m: usize) Node {
            return Node{
                .p = p,
                .m = m,
                .n = std.AutoHashMap(u64, void).init(std.heap.direct_allocator),
            };
        }

        pub fn deinit(self: *Node) void {
            self.n.deinit();
        }

        pub fn encode(self: Node) u64 {
            return (self.m * 1000 + self.p.x) * 1000 + self.p.y;
        }

        pub fn get_mask(label: u64) usize {
            return label / 1000000;
        }

        fn lessThan(l: Node, r: Node) bool {
            if (l.m < r.m) return true;
            if (l.m > r.m) return false;
            if (Pos.lessThan(l.p, r.p)) return true;
            if (Pos.lessThan(r.p, l.p)) return false;
            return false;
        }
    };

    pub const NodeInfo = struct {
        label: u64,
        dist: usize,

        pub fn init(label: u64, dist: usize) NodeInfo {
            return NodeInfo{
                .label = label,
                .dist = dist,
            };
        }

        fn lessThan(l: NodeInfo, r: NodeInfo) bool {
            if (l.dist < r.dist) return true;
            if (l.dist > r.dist) return false;
            if (l.label < r.label) return true;
            if (l.label > r.label) return false;
            return false;
        }
    };

    cells: std.AutoHashMap(Pos, Tile),
    keys: std.AutoHashMap(Pos, u8),
    doors: std.AutoHashMap(Pos, u8),
    nodes: std.AutoHashMap(u64, Node),
    py: usize,
    pcur: Pos,
    pmin: Pos,
    pmax: Pos,

    pub const Dir = enum(u8) {
        N = 1,
        S = 2,
        W = 3,
        E = 4,

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

    pub const Tile = enum(u8) {
        Empty = 0,
        Wall = 1,
        Door = 2,
        Key = 3,
    };

    pub fn init() Map {
        var self = Map{
            .py = 0,
            .cells = std.AutoHashMap(Pos, Tile).init(std.heap.direct_allocator),
            .keys = std.AutoHashMap(Pos, u8).init(std.heap.direct_allocator),
            .doors = std.AutoHashMap(Pos, u8).init(std.heap.direct_allocator),
            .nodes = std.AutoHashMap(u64, Node).init(std.heap.direct_allocator),
            .pcur = Pos.init(Pos.OFFSET / 2, Pos.OFFSET / 2),
            .pmin = Pos.init(std.math.maxInt(usize), std.math.maxInt(usize)),
            .pmax = Pos.init(0, 0),
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.nodes.deinit();
        self.doors.deinit();
        self.keys.deinit();
        self.cells.deinit();
    }

    pub fn parse(self: *Map, line: []const u8) void {
        var x: usize = 0;
        while (x < line.len) : (x += 1) {
            const p = Pos.init(x, self.py);
            var t: Map.Tile = Map.Tile.Empty;
            if (line[x] == '#') t = Map.Tile.Wall;
            if (line[x] == '@') {
                self.pcur = p;
            }
            if (line[x] >= 'A' and line[x] <= 'Z') {
                // std.debug.warn("DOOR {c}\n", line[x]);
                t = Map.Tile.Door;
                _ = self.doors.put(p, line[x]) catch unreachable;
            }
            if (line[x] >= 'a' and line[x] <= 'z') {
                // std.debug.warn("KEY {c}\n", line[x]);
                t = Map.Tile.Key;
                _ = self.keys.put(p, line[x]) catch unreachable;
            }
            self.set_pos(p, t);
        }
        self.py += 1;
    }

    pub fn set_pos(self: *Map, pos: Pos, mark: Tile) void {
        _ = self.cells.put(pos, mark) catch unreachable;
        if (self.pmin.x > pos.x) self.pmin.x = pos.x;
        if (self.pmin.y > pos.y) self.pmin.y = pos.y;
        if (self.pmax.x < pos.x) self.pmax.x = pos.x;
        if (self.pmax.y < pos.y) self.pmax.y = pos.y;
    }

    pub fn walk_map(self: *Map) void {
        var allocator = std.heap.direct_allocator;

        const all_keys = self.get_all_keys();
        self.nodes.clear();

        const PQ = std.PriorityQueue(Node);
        var Pend = PQ.init(allocator, Node.lessThan);
        defer Pend.deinit();

        // We start from the oxygen system position, which has already been filled with oxygen
        const first = Node.init(self.pcur, 0);
        _ = Pend.add(first) catch unreachable;
        while (Pend.count() != 0) {
            var curr = Pend.remove();
            if (self.nodes.contains(curr.encode())) continue;
            if (curr.m == self.get_all_keys()) continue;

            var j: u8 = 1;
            while (j <= 4) : (j += 1) {
                const d = @intToEnum(Dir, j);
                var v = Dir.move(curr.p, d);
                if (!self.cells.contains(v)) continue;
                const tile = self.cells.get(v).?.value;
                var next: ?Node = null;
                switch (tile) {
                    Tile.Wall => {},
                    Tile.Empty => {
                        next = Node.init(v, curr.m);
                    },
                    Tile.Key => {
                        const shift: u5 = @intCast(u5, self.keys.get(v).?.value - 'a');
                        const needed: usize = @shlExact(@intCast(usize, 1), shift);
                        next = Node.init(v, curr.m | needed);
                    },
                    Tile.Door => {
                        if (!self.doors.contains(v)) {
                            next = Node.init(v, curr.m);
                        } else {
                            const shift: u5 = @intCast(u5, self.doors.get(v).?.value - 'A');
                            const needed: usize = @shlExact(@intCast(usize, 1), shift);
                            if (curr.m & needed != 0) {
                                next = Node.init(v, curr.m);
                            }
                        }
                    },
                }
                if (next == null) continue;
                const n = next.?;
                const e = n.encode();
                _ = curr.n.put(e, {}) catch unreachable;
                if (self.nodes.contains(e)) continue;
                _ = Pend.add(n) catch unreachable;
            }
            _ = self.nodes.put(curr.encode(), curr) catch unreachable;
        }
        // std.debug.warn("Graph has {} nodes\n", self.nodes.count());
    }

    pub fn walk_graph(self: *Map) usize {
        var allocator = std.heap.direct_allocator;

        var seen = std.AutoHashMap(u64, void).init(allocator);
        defer seen.deinit();

        const PQ = std.PriorityQueue(NodeInfo);
        var Pend = PQ.init(allocator, NodeInfo.lessThan);
        defer Pend.deinit();

        const all_keys = self.get_all_keys();

        var dmax: usize = 0;
        const home = Node.init(self.pcur, 0);
        const first = NodeInfo.init(home.encode(), 0);
        _ = Pend.add(first) catch unreachable;
        while (Pend.count() != 0) {
            const data = Pend.remove();
            const x = Node.get_mask(data.label);
            if (dmax < data.dist) dmax = data.dist;
            if (Node.get_mask(data.label) == all_keys) break;
            const node = self.nodes.get(data.label).?.value;
            const dist = data.dist + 1;
            var it = node.n.iterator();
            while (it.next()) |kv| {
                const l = kv.key;
                if (seen.contains(l)) continue;
                _ = seen.put(l, {}) catch unreachable;
                _ = Pend.add(NodeInfo.init(l, dist)) catch unreachable;
            }
        }
        return dmax;
    }

    fn get_all_keys(self: *Map) usize {
        var all_keys: usize = 0;
        var it = self.keys.iterator();
        while (it.next()) |key| {
            const shift: u5 = @intCast(u5, key.value - 'a');
            const mask: usize = @shlExact(@intCast(usize, 1), shift);
            all_keys |= mask;
        }
        return all_keys;
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
                        Tile.Door => t = self.doors.get(p).?.value,
                        Tile.Key => t = self.keys.get(p).?.value,
                    }
                }
                if (x == self.pcur.x and y == self.pcur.y) t = '@';
                std.debug.warn("{c}", t);
            }
            std.debug.warn("\n");
        }
    }
};

test "small map" {
    var map = Map.init();
    defer map.deinit();

    const data =
        \\#########
        \\#b.A.@.a#
        \\#########
    ;
    var it = std.mem.separate(data, "\n");
    while (it.next()) |line| {
        map.parse(line);
    }
    // map.show();
    map.walk_map();
    const dist = map.walk_graph();
    assert(dist == 8);
}

test "medium map 1" {
    var map = Map.init();
    defer map.deinit();

    const data =
        \\########################
        \\#f.D.E.e.C.b.A.@.a.B.c.#
        \\######################.#
        \\#d.....................#
        \\########################
    ;
    var it = std.mem.separate(data, "\n");
    while (it.next()) |line| {
        map.parse(line);
    }
    // map.show();
    map.walk_map();
    const dist = map.walk_graph();
    assert(dist == 86);
}

test "medium map 2" {
    var map = Map.init();
    defer map.deinit();

    const data =
        \\########################
        \\#...............b.C.D.f#
        \\#.######################
        \\#.....@.a.B.c.d.A.e.F.g#
        \\########################
    ;
    var it = std.mem.separate(data, "\n");
    while (it.next()) |line| {
        map.parse(line);
    }
    // map.show();
    map.walk_map();
    const dist = map.walk_graph();
    assert(dist == 132);
}

test "medium map 3" {
    var map = Map.init();
    defer map.deinit();

    const data =
        \\#################
        \\#i.G..c...e..H.p#
        \\########.########
        \\#j.A..b...f..D.o#
        \\########@########
        \\#k.E..a...g..B.n#
        \\########.########
        \\#l.F..d...h..C.m#
        \\#################
    ;
    var it = std.mem.separate(data, "\n");
    while (it.next()) |line| {
        map.parse(line);
    }
    // map.show();
    map.walk_map();
    const dist = map.walk_graph();
    assert(dist == 136);
}

test "medium map 4" {
    var map = Map.init();
    defer map.deinit();

    const data =
        \\########################
        \\#@..............ac.GI.b#
        \\###d#e#f################
        \\###A#B#C################
        \\###g#h#i################
        \\########################
    ;
    var it = std.mem.separate(data, "\n");
    while (it.next()) |line| {
        map.parse(line);
    }
    // map.show();
    map.walk_map();
    const dist = map.walk_graph();
    assert(dist == 81);
}
