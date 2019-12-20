const std = @import("std");
const assert = std.debug.assert;

const MAX_DEPTH = 500;

pub const Map = struct {
    pub const Pos = struct {
        const OFFSET: usize = 1000;

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

    pub const PortalName = struct {
        where: u8,
        label: u8,

        pub fn init(where: u8, label: u8) PortalName {
            return PortalName{
                .where = where,
                .label = label,
            };
        }
    };

    cells: std.AutoHashMap(Pos, Tile),
    portals: std.AutoHashMap(Pos, Pos),
    outer: std.AutoHashMap(Pos, void),
    one: std.AutoHashMap(Pos, PortalName),
    two: std.AutoHashMap(usize, Pos),
    graph: std.AutoHashMap(Pos, std.AutoHashMap(Pos, usize)),
    py: usize,
    ymin: usize,
    ymax: usize,
    pmin: Pos,
    pmax: Pos,
    psrc: Pos,
    ptgt: Pos,

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

    pub const Tile = enum(u8) {
        Empty = 0,
        Passage = 1,
        Wall = 2,
        Portal = 3,
    };

    pub fn init() Map {
        var allocator = std.heap.direct_allocator;
        var self = Map{
            .cells = std.AutoHashMap(Pos, Tile).init(allocator),
            .one = std.AutoHashMap(Pos, PortalName).init(allocator),
            .two = std.AutoHashMap(usize, Pos).init(allocator),
            .graph = std.AutoHashMap(Pos, std.AutoHashMap(Pos, usize)).init(allocator),
            .portals = std.AutoHashMap(Pos, Pos).init(allocator),
            .outer = std.AutoHashMap(Pos, void).init(allocator),
            .pmin = Pos.init(std.math.maxInt(usize), std.math.maxInt(usize)),
            .pmax = Pos.init(0, 0),
            .psrc = Pos.init(0, 0),
            .ptgt = Pos.init(0, 0),
            .py = 0,
            .ymin = std.math.maxInt(usize),
            .ymax = 0,
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.outer.deinit();
        self.portals.deinit();
        self.graph.deinit();
        self.two.deinit();
        self.one.deinit();
        self.cells.deinit();
    }

    pub fn parse(self: *Map, line: []const u8) void {
        var where: u8 = 0;
        var x: usize = 0;
        while (x < line.len) : (x += 1) {
            if (line[x] == ' ') {
                if (where == 1) where = 2;
                if (where == 3) where = 4;
                continue;
            }
            var p = Pos.init(x + Pos.OFFSET, self.py + Pos.OFFSET);
            var t: Tile = undefined;
            if (line[x] == '.') t = Tile.Passage;
            if (line[x] == '#') {
                if (self.ymin > p.y) self.ymin = p.y;
                if (self.ymax < p.y) self.ymax = p.y;
                if (where == 0) where = 1;
                if (where == 2) where = 3;
                t = Tile.Wall;
            }
            if (line[x] >= 'A' and line[x] <= 'Z') {
                if (where == 1) where = 2;
                if (where == 3) where = 4;
                t = Tile.Portal;
                _ = self.one.put(p, PortalName.init(where, line[x])) catch unreachable;
            }
            self.set_pos(p, t);
        }
        self.py += 1;
    }

    pub const Label = struct {
        fn encode(l0: u8, l1: u8) usize {
            return @intCast(usize, l0) * 1000 + @intCast(usize, l1);
        }
        fn decode(l: usize) void {
            var v: usize = l;
            const l1 = @intCast(u8, v % 1000);
            v /= 1000;
            const l0 = @intCast(u8, v % 1000);
            std.debug.warn("LABEL: [{c}{c}]\n", l0, l1);
        }
    };

    pub fn find_portals(self: *Map) void {
        var allocator = std.heap.direct_allocator;
        var seen = std.AutoHashMap(Pos, void).init(allocator);
        defer seen.deinit();

        const lAA = Label.encode('A', 'A');
        const lZZ = Label.encode('Z', 'Z');
        var y: usize = self.pmin.y;
        while (y <= self.pmax.y) : (y += 1) {
            var x: usize = self.pmin.x;
            while (x <= self.pmax.x) : (x += 1) {
                var pc = Pos.init(x, y);
                var tc = self.get_pos(pc);
                if (tc != Tile.Portal) continue;
                if (seen.contains(pc)) continue;
                const x0 = self.one.get(pc).?.value;
                const l0 = x0.label;
                _ = self.one.remove(pc);
                // std.debug.warn("LOOKING at portal {c} {}\n", l0, pc);
                var k: u8 = 1;
                while (k <= 4) : (k += 1) {
                    const d = @intToEnum(Dir, k);
                    const r = Dir.reverse(d);
                    const pn = Dir.move(pc, d);
                    var tn = self.get_pos(pn);
                    if (tn != Tile.Portal) continue;
                    if (seen.contains(pn)) continue;
                    _ = seen.put(pc, {}) catch unreachable;
                    _ = seen.put(pn, {}) catch unreachable;

                    const x1 = self.one.get(pn).?.value;
                    const l1 = x1.label;
                    if (x0.where != x1.where) {
                        std.debug.warn("FUCKERS!\n");
                        break;
                    }
                    _ = self.one.remove(pn);
                    var label = Label.encode(l0, l1);
                    // std.debug.warn("PORTAL {c}{c} in area {}\n", l0, l1, x0.where);

                    var p0 = Dir.move(pn, d);
                    var pt = self.get_pos(p0);
                    if (pt != Tile.Passage) {
                        p0 = Dir.move(pc, r);
                        pt = self.get_pos(p0);
                    }
                    if (pt != Tile.Passage) {
                        std.debug.warn("FUCK\n");
                    }

                    if (x0.where == 0 or x0.where == 4 or
                        (x0.where == 1 and (p0.y == self.ymin or p0.y == self.ymax)))
                    {
                        _ = self.outer.put(p0, {}) catch unreachable;
                    }

                    if (label == lAA) {
                        self.psrc = p0;
                        _ = self.portals.put(p0, p0) catch unreachable;
                        break;
                    }
                    if (label == lZZ) {
                        self.ptgt = p0;
                        _ = self.portals.put(p0, p0) catch unreachable;
                        break;
                    }

                    if (self.two.contains(label)) {
                        // found second endpoint of a portal
                        const p1 = self.two.get(label).?.value;
                        // std.debug.warn("SECOND pos for label {}: {}\n", label, p0);
                        // std.debug.warn("PORTAL SECOND [{}] {} {}\n", label, p0, p1);
                        _ = self.portals.put(p0, p1) catch unreachable;
                        _ = self.portals.put(p1, p0) catch unreachable;
                        _ = self.two.remove(label);
                    } else {
                        // found first endpoint of a portal
                        // std.debug.warn("PORTAL FIRST [{}] {}\n", label, p0);
                        _ = self.two.put(label, p0) catch unreachable;
                        // std.debug.warn("FIRST pos for label {}: {}\n", label, p0);
                    }
                    break;
                }
            }
        }
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

    pub fn find_graph(self: *Map) void {
        var allocator = std.heap.direct_allocator;

        self.graph.clear();
        var it = self.portals.iterator();
        while (it.next()) |kv| {
            const portal = kv.key;
            var reach = std.AutoHashMap(Pos, usize).init(allocator);

            var seen = std.AutoHashMap(Pos, void).init(allocator);
            defer seen.deinit();

            const PQ = std.PriorityQueue(PosDist);
            var Pend = PQ.init(allocator, PosDist.lessThan);
            defer Pend.deinit();

            _ = Pend.add(PosDist.init(portal, 0)) catch unreachable;
            while (Pend.count() != 0) {
                const data = Pend.remove();
                if (!data.pos.equal(portal) and self.portals.contains(data.pos)) {
                    _ = reach.put(data.pos, data.dist) catch unreachable;
                }
                _ = seen.put(data.pos, {}) catch unreachable;
                const dist = data.dist + 1;
                var j: u8 = 1;
                while (j <= 4) : (j += 1) {
                    const d = @intToEnum(Dir, j);
                    var v = Dir.move(data.pos, d);
                    if (!self.cells.contains(v)) continue;
                    if (seen.contains(v)) continue;
                    const tile = self.cells.get(v).?.value;
                    if (tile != Tile.Passage) continue;
                    _ = Pend.add(PosDist.init(v, dist)) catch unreachable;
                }
            }
            _ = self.graph.put(portal, reach) catch unreachable;
            // std.debug.warn("FROM portal {} {}:\n", portal.x - 1000, portal.y - 1000);
            // var itr = reach.iterator();
            // while (itr.next()) |kvr| {
            //     std.debug.warn("- portal {} {} dist {}:\n", kvr.key.x - 1000, kvr.key.y - 1000, kvr.value);
            // }
        }
    }

    pub const PortalInfo = struct {
        pos: Pos,
        depth: usize,

        pub fn init(pos: Pos, depth: usize) PortalInfo {
            return PortalInfo{
                .pos = pos,
                .depth = depth,
            };
        }

        pub fn equal(self: PortalInfo, other: PortalInfo) bool {
            return self.depth == other.depth and self.pos.equal(other.pos);
        }
    };

    // Long live the master, Edsger W. Dijkstra
    // https://en.wikipedia.org/wiki/Dijkstra%27s_algorithm
    pub fn find_path_to_target(self: *Map, recursive: bool) usize {
        var allocator = std.heap.direct_allocator;
        var Pend = std.AutoHashMap(PortalInfo, void).init(allocator);
        defer Pend.deinit();
        var Dist = std.AutoHashMap(PortalInfo, usize).init(allocator);
        defer Dist.deinit();
        var Path = std.AutoHashMap(PortalInfo, PortalInfo).init(allocator);
        defer Path.deinit();

        // Fill Pend for all nodes
        var depth: usize = 0;
        while (depth < MAX_DEPTH) : (depth += 1) {
            var itg = self.graph.iterator();
            while (itg.next()) |kvg| {
                const p = kvg.key;
                const pi = PortalInfo.init(p, depth);
                _ = Pend.put(pi, {}) catch unreachable;
            }
            if (!recursive) break;
        }
        const ps = PortalInfo.init(self.psrc, 0);
        var pt = PortalInfo.init(self.ptgt, 0);
        _ = Dist.put(ps, 0) catch unreachable;
        while (Pend.count() != 0) {
            // Search for a pending node with minimal distance
            // TODO: we could use a PriorityQueue here to quickly get at the
            // node, but we will also need to update the node's distance later,
            // which would mean re-shuffling the PQ; not sure how to do this.
            var pu: PortalInfo = undefined;
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
                    pu = found.key;
                }
            }
            var u: Pos = pu.pos;
            if (dmin == std.math.maxInt(usize)) {
                return 0;
            }
            _ = Pend.remove(pu);
            if (pu.equal(pt)) {
                // node chosen is our target, we can stop searching now
                break;
            }

            // update dist for all neighbours of u
            // add closest neighbour of u to the path
            const du = Dist.get(pu).?.value;
            const neighbours = self.graph.get(u).?.value;
            // std.debug.warn("CONSIDER {} {} depth {} distance {} neighbours {}\n", u.x - 1000, u.y - 1000, pu.depth, du, neighbours.count());
            var itn = neighbours.iterator();
            while (itn.next()) |kvn| {
                var dd: i32 = 0;
                var v = kvn.key;
                const outer = self.outer.contains(v);
                const IS = v.equal(self.psrc);
                const IT = v.equal(self.ptgt);
                if (recursive) {
                    if (outer) {
                        if (pu.depth > 0) {
                            if (IS or IT) {
                                continue;
                            } else {
                                dd = -1;
                            }
                        } else {
                            if (IS or IT) {} else {
                                continue;
                            }
                        }
                    } else {
                        if (IS) continue;
                        if (IT) continue;
                        dd = 1;
                    }
                }
                const nd = @intCast(i32, pu.depth) + dd;
                var t = self.portals.get(v).?.value;
                var alt = du + kvn.value;
                if (t.equal(v) or IS or IT) {} else {
                    v = t;
                    alt += 1;
                }
                var pv = PortalInfo.init(v, @intCast(usize, nd));
                var dv: usize = std.math.maxInt(usize);
                if (Dist.contains(pv)) dv = Dist.get(pv).?.value;
                if (alt < dv) {
                    // std.debug.warn("UPDATE {} {} distance {}\n", v.x - 1000, v.y - 1000, alt);
                    _ = Dist.put(pv, alt) catch unreachable;
                    _ = Path.put(pv, pu) catch unreachable;
                }
            }
        }

        const dist = Dist.get(pt).?.value;
        return dist;
    }

    pub fn get_pos(self: *Map, pos: Pos) Tile {
        if (!self.cells.contains(pos)) return Tile.Empty;
        return self.cells.get(pos).?.value;
    }

    pub fn set_pos(self: *Map, pos: Pos, mark: Tile) void {
        _ = self.cells.put(pos, mark) catch unreachable;
        if (self.pmin.x > pos.x) self.pmin.x = pos.x;
        if (self.pmin.y > pos.y) self.pmin.y = pos.y;
        if (self.pmax.x < pos.x) self.pmax.x = pos.x;
        if (self.pmax.y < pos.y) self.pmax.y = pos.y;
    }

    pub fn show(self: Map) void {
        const sx = self.pmax.x - self.pmin.x + 1;
        const sy = self.pmax.y - self.pmin.y + 1;
        std.debug.warn("MAP: {} x {} - {} {} - {} {}\n", sx, sy, self.pmin.x, self.pmin.y, self.pmax.x, self.pmax.y);
        std.debug.warn("SRC: {}  -- TGT {}\n", self.psrc, self.ptgt);
        var y: usize = self.pmin.y;
        while (y <= self.pmax.y) : (y += 1) {
            std.debug.warn("{:4} | ", y);
            var x: usize = self.pmin.x;
            while (x <= self.pmax.x) : (x += 1) {
                const p = Pos.init(x, y);
                const t = self.cells.get(p);
                var c: u8 = ' ';
                if (t != null) {
                    switch (t.?.value) {
                        Tile.Empty => c = ' ',
                        Tile.Passage => c = '.',
                        Tile.Wall => c = '#',
                        Tile.Portal => c = 'X',
                    }
                }
                std.debug.warn("{c}", c);
            }
            std.debug.warn("\n");
        }
        var it = self.portals.iterator();
        while (it.next()) |kv| {
            std.debug.warn("Portal: {} to {}\n", kv.key, kv.value);
        }
    }
};

test "small maze" {
    var map = Map.init();
    defer map.deinit();

    const data =
        \\         A
        \\         A
        \\  #######.#########
        \\  #######.........#
        \\  #######.#######.#
        \\  #######.#######.#
        \\  #######.#######.#
        \\  #####  B    ###.#
        \\BC...##  C    ###.#
        \\  ##.##       ###.#
        \\  ##...DE  F  ###.#
        \\  #####    G  ###.#
        \\  #########.#####.#
        \\DE..#######...###.#
        \\  #.#########.###.#
        \\FG..#########.....#
        \\  ###########.#####
        \\             Z
        \\             Z
    ;
    var it = std.mem.separate(data, "\n");
    while (it.next()) |line| {
        map.parse(line);
    }
    map.find_portals();
    map.find_graph();
    // map.show();

    assert(map.one.count() == 0);
    assert(map.two.count() == 0);
    assert(map.psrc.equal(Map.Pos.init(9 + Map.Pos.OFFSET, 2 + Map.Pos.OFFSET)));
    assert(map.ptgt.equal(Map.Pos.init(13 + Map.Pos.OFFSET, 16 + Map.Pos.OFFSET)));

    const result = map.find_path_to_target(false);
    assert(result == 23);
}

test "medium maze" {
    var map = Map.init();
    defer map.deinit();

    const data =
        \\                   A
        \\                   A
        \\  #################.#############
        \\  #.#...#...................#.#.#
        \\  #.#.#.###.###.###.#########.#.#
        \\  #.#.#.......#...#.....#.#.#...#
        \\  #.#########.###.#####.#.#.###.#
        \\  #.............#.#.....#.......#
        \\  ###.###########.###.#####.#.#.#
        \\  #.....#        A   C    #.#.#.#
        \\  #######        S   P    #####.#
        \\  #.#...#                 #......VT
        \\  #.#.#.#                 #.#####
        \\  #...#.#               YN....#.#
        \\  #.###.#                 #####.#
        \\DI....#.#                 #.....#
        \\  #####.#                 #.###.#
        \\ZZ......#               QG....#..AS
        \\  ###.###                 #######
        \\JO..#.#.#                 #.....#
        \\  #.#.#.#                 ###.#.#
        \\  #...#..DI             BU....#..LF
        \\  #####.#                 #.#####
        \\YN......#               VT..#....QG
        \\  #.###.#                 #.###.#
        \\  #.#...#                 #.....#
        \\  ###.###    J L     J    #.#.###
        \\  #.....#    O F     P    #.#...#
        \\  #.###.#####.#.#####.#####.###.#
        \\  #...#.#.#...#.....#.....#.#...#
        \\  #.#####.###.###.#.#.#########.#
        \\  #...#.#.....#...#.#.#.#.....#.#
        \\  #.###.#####.###.###.#.#.#######
        \\  #.#.........#...#.............#
        \\  #########.###.###.#############
        \\           B   J   C
        \\           U   P   P
    ;
    var it = std.mem.separate(data, "\n");
    while (it.next()) |line| {
        map.parse(line);
    }
    map.find_portals();
    map.find_graph();
    // map.show();

    assert(map.one.count() == 0);
    assert(map.two.count() == 0);

    const result = map.find_path_to_target(false);
    assert(result == 58);
}

test "small maze recursive" {
    var map = Map.init();
    defer map.deinit();

    const data =
        \\         A
        \\         A
        \\  #######.#########
        \\  #######.........#
        \\  #######.#######.#
        \\  #######.#######.#
        \\  #######.#######.#
        \\  #####  B    ###.#
        \\BC...##  C    ###.#
        \\  ##.##       ###.#
        \\  ##...DE  F  ###.#
        \\  #####    G  ###.#
        \\  #########.#####.#
        \\DE..#######...###.#
        \\  #.#########.###.#
        \\FG..#########.....#
        \\  ###########.#####
        \\             Z
        \\             Z
    ;
    var it = std.mem.separate(data, "\n");
    while (it.next()) |line| {
        map.parse(line);
    }
    map.find_portals();
    map.find_graph();
    // map.show();

    assert(map.one.count() == 0);
    assert(map.two.count() == 0);
    assert(map.psrc.equal(Map.Pos.init(9 + Map.Pos.OFFSET, 2 + Map.Pos.OFFSET)));
    assert(map.ptgt.equal(Map.Pos.init(13 + Map.Pos.OFFSET, 16 + Map.Pos.OFFSET)));

    const result = map.find_path_to_target(true);
    assert(result == 26);
}

test "medium maze recursive" {
    var map = Map.init();
    defer map.deinit();

    const data =
        \\             Z L X W       C
        \\             Z P Q B       K
        \\  ###########.#.#.#.#######.###############
        \\  #...#.......#.#.......#.#.......#.#.#...#
        \\  ###.#.#.#.#.#.#.#.###.#.#.#######.#.#.###
        \\  #.#...#.#.#...#.#.#...#...#...#.#.......#
        \\  #.###.#######.###.###.#.###.###.#.#######
        \\  #...#.......#.#...#...#.............#...#
        \\  #.#########.#######.#.#######.#######.###
        \\  #...#.#    F       R I       Z    #.#.#.#
        \\  #.###.#    D       E C       H    #.#.#.#
        \\  #.#...#                           #...#.#
        \\  #.###.#                           #.###.#
        \\  #.#....OA                       WB..#.#..ZH
        \\  #.###.#                           #.#.#.#
        \\CJ......#                           #.....#
        \\  #######                           #######
        \\  #.#....CK                         #......IC
        \\  #.###.#                           #.###.#
        \\  #.....#                           #...#.#
        \\  ###.###                           #.#.#.#
        \\XF....#.#                         RF..#.#.#
        \\  #####.#                           #######
        \\  #......CJ                       NM..#...#
        \\  ###.#.#                           #.###.#
        \\RE....#.#                           #......RF
        \\  ###.###        X   X       L      #.#.#.#
        \\  #.....#        F   Q       P      #.#.#.#
        \\  ###.###########.###.#######.#########.###
        \\  #.....#...#.....#.......#...#.....#.#...#
        \\  #####.#.###.#######.#######.###.###.#.#.#
        \\  #.......#.......#.#.#.#.#...#...#...#.#.#
        \\  #####.###.#####.#.#.#.#.###.###.#.###.###
        \\  #.......#.....#.#...#...............#...#
        \\  #############.#.#.###.###################
        \\               A O F   N
        \\               A A D   M
    ;
    var it = std.mem.separate(data, "\n");
    while (it.next()) |line| {
        map.parse(line);
    }
    map.find_portals();
    map.find_graph();
    // map.show();

    const result = map.find_path_to_target(true);
    assert(result == 396);
}
