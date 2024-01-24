const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Factory = struct {
    const StringId = StringTable.StringId;
    const Floor = u2;
    const Pair = u4;

    const INFINITY = std.math.maxInt(usize);
    const MAX_FLOORS = 4;
    const MAX_COMPONENTS = 7;
    const Ordinals = [_][]const u8{ "first", "second", "third", "fourth" };

    const Component = struct {
        id: usize,
        name: StringId,
        floor_g: usize,
        floor_m: usize,

        pub fn init(id: usize, name: StringId) Component {
            return Component{ .id = id, .name = name, .floor_g = 0, .floor_m = 0 };
        }
    };

    allocator: Allocator,
    use_extra: bool,
    strtab: StringTable,
    floor: usize,
    components: std.AutoHashMap(StringId, Component),

    pub fn init(allocator: Allocator, use_extra: bool) Factory {
        return Factory{
            .allocator = allocator,
            .use_extra = use_extra,
            .strtab = StringTable.init(allocator),
            .floor = 0,
            .components = std.AutoHashMap(StringId, Component).init(allocator),
        };
    }

    pub fn deinit(self: *Factory) void {
        self.components.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Factory, line: []const u8) !void {
        var it_line = std.mem.tokenizeAny(u8, line, " .,");
        _ = it_line.next();
        const name_floor = it_line.next().?;
        std.debug.assert(std.mem.eql(u8, name_floor, Ordinals[self.floor]));
        _ = it_line.next();
        _ = it_line.next();
        while (it_line.next()) |chunk| {
            var qualifier = chunk;
            if (std.mem.eql(u8, qualifier, "and")) qualifier = it_line.next().?;
            if (std.mem.eql(u8, qualifier, "nothing")) {
                break;
            }
            const next = it_line.next().?;
            var it_piece = std.mem.tokenizeScalar(u8, next, '-');
            const element = it_piece.next().?;
            const kind = it_line.next().?;
            if (std.mem.eql(u8, kind, "microchip")) {
                const m = try self.addComponent(element);
                m.*.floor_m = self.floor;
                continue;
            }
            if (std.mem.eql(u8, kind, "generator")) {
                const g = try self.addComponent(element);
                g.*.floor_g = self.floor;
                continue;
            }
            return error.InvalidData;
        }
        self.floor += 1;
    }

    fn addComponent(self: *Factory, name: []const u8) !*Component {
        const strid = try self.strtab.add(name);
        const id = self.components.count();
        const r = try self.components.getOrPut(strid);
        if (!r.found_existing) {
            r.value_ptr.* = Component.init(id, strid);
        }
        return r.value_ptr;
    }

    pub fn show(self: Factory) void {
        std.debug.print("Factory with {} components\n", .{self.components.count()});
        var it = self.components.valueIterator();
        while (it.next()) |c| {
            std.debug.print("G{} M{} for [{s}]\n", .{
                c.floor_g,
                c.floor_m,
                self.strtab.get_str(c.name) orelse "***",
            });
        }
    }

    const State = struct {
        fl: Floor,
        nc: usize,
        fg: [MAX_COMPONENTS]Floor,
        fm: [MAX_COMPONENTS]Floor,

        pub fn init(components: usize, floor: usize) State {
            return State{
                .fl = @intCast(floor),
                .nc = components,
                .fg = [_]Floor{0} ** MAX_COMPONENTS,
                .fm = [_]Floor{0} ** MAX_COMPONENTS,
            };
        }

        pub fn show(self: State) void {
            std.debug.print("------------------\n", .{});
            for (0..MAX_FLOORS) |floor| {
                const f = MAX_FLOORS - floor - 1;
                const l: u8 = if (f == self.fl) 'E' else ' ';
                std.debug.print("F{} {c}", .{ f, l });
                for (0..self.nc) |c| {
                    if (self.fg[c] != f) continue;
                    std.debug.print(" G{}", .{c});
                }
                for (0..self.nc) |c| {
                    if (self.fm[c] != f) continue;
                    std.debug.print(" M{}", .{c});
                }
                std.debug.print("\n", .{});
            }
        }

        pub fn fingerprint(self: State) u64 {
            var cbuf: [MAX_COMPONENTS]Pair = [_]Pair{0} ** MAX_COMPONENTS;
            for (0..self.nc) |c| {
                cbuf[c] = self.fg[c];
                cbuf[c] <<= 2;
                cbuf[c] |= self.fm[c];
            }
            std.sort.insertion(Pair, cbuf[0..self.nc], {}, std.sort.asc(Pair));
            // cbuf is [7]u4, but has a size of 52 bits...
            const tmp: u52 = @bitCast(cbuf);
            var mask: u64 = @intCast(tmp);
            mask <<= 2;
            mask |= @intCast(self.fl);
            return mask;
        }

        fn isValid(self: State) bool {
            var gf: [MAX_FLOORS]usize = [_]usize{0} ** MAX_FLOORS;
            for (0..self.nc) |c| {
                gf[self.fg[c]] += 1;
            }
            for (0..self.nc) |c| {
                const fm = self.fm[c];
                if (fm == self.fg[c]) continue;
                if (gf[fm] > 0) return false;
            }
            return true;
        }
    };

    const StateDist = struct {
        state: State,
        dist: usize,

        pub fn init(state: State, dist: usize) StateDist {
            return StateDist{ .state = state, .dist = dist };
        }

        fn lessThan(_: void, l: StateDist, r: StateDist) std.math.Order {
            return std.math.order(l.dist, r.dist);
        }
    };

    pub fn findShortestSteps(self: *Factory) !usize {
        if (self.use_extra) {
            _ = try self.addComponent("elerium");
            _ = try self.addComponent("dilithium");
        }
        self.show();

        const tgt_floor: Floor = @intCast(self.floor - 1);
        var src = State.init(self.components.count(), 0);
        var tgt = State.init(self.components.count(), tgt_floor);

        var it = self.components.valueIterator();
        while (it.next()) |c| {
            src.fg[c.id] = @intCast(c.floor_g);
            tgt.fg[c.id] = tgt_floor;
            src.fm[c.id] = @intCast(c.floor_m);
            tgt.fm[c.id] = tgt_floor;
        }
        // src.show();
        // tgt.show();

        var search = AStar.init(self.allocator, self.floor);
        defer search.deinit();
        const dist = search.run(src, tgt);
        std.debug.print("Visited {} nodes\n", .{search.seen.count()});
        return dist;
    }

    const AStar = struct {
        floors: usize,
        seen: std.AutoHashMap(u64, void), // nodes we have already visited
        distance: std.AutoHashMap(State, usize), // lowest distance so far to each node
        pending: std.PriorityQueue(StateDist, void, StateDist.lessThan), // pending nodes to visit

        pub fn init(allocator: Allocator, floors: usize) AStar {
            return AStar{
                .floors = floors,
                .seen = std.AutoHashMap(u64, void).init(allocator),
                .pending = std.PriorityQueue(StateDist, void, StateDist.lessThan).init(allocator, {}),
                .distance = std.AutoHashMap(State, usize).init(allocator),
            };
        }

        pub fn deinit(self: *AStar) void {
            self.distance.deinit();
            self.pending.deinit();
            self.seen.deinit();
        }

        pub fn run(self: *AStar, src: State, tgt: State) !usize {
            try self.distance.put(src, 0);
            try self.pending.add(StateDist.init(src, 0));
            while (self.pending.count() != 0) {
                const sd = self.pending.remove();
                const u = sd.state;
                // u.show();
                // std.debug.print("distance so far: {}\n", .{sd.dist});
                const fp = u.fingerprint();
                if (fp == tgt.fingerprint()) return sd.dist; // found target!
                _ = try self.seen.put(fp, {});

                const uf = u.fl;

                var gbuf: [MAX_COMPONENTS]usize = [_]usize{0} ** MAX_COMPONENTS;
                var gpos: usize = 0;
                var mbuf: [MAX_COMPONENTS]usize = [_]usize{0} ** MAX_COMPONENTS;
                var mpos: usize = 0;
                var xbuf: [MAX_COMPONENTS]usize = [_]usize{0} ** MAX_COMPONENTS;
                var xpos: usize = 0;
                for (0..u.nc) |c| {
                    const mf = u.fm[c] == uf;
                    const gf = u.fg[c] == uf;
                    if (mf) {
                        mbuf[mpos] = c;
                        mpos += 1;
                    }
                    if (gf) {
                        gbuf[gpos] = c;
                        gpos += 1;
                    }
                    if (mf and gf) {
                        xbuf[xpos] = c;
                        xpos += 1;
                    }
                }

                var fbuf: [2]usize = undefined;
                var fpos: usize = 0;
                if (uf > 0) {
                    fbuf[fpos] = uf - 1;
                    fpos += 1;
                }
                if (uf < self.floors - 1) {
                    fbuf[fpos] = uf + 1;
                    fpos += 1;
                }
                for (fbuf[0..fpos]) |vf| {
                    const floor: Floor = @intCast(vf);

                    // try taking one or two microchips
                    for (0..mpos) |p1| {
                        const m1 = mbuf[p1];
                        var v1 = u;
                        v1.fl = floor;
                        v1.fm[m1] = floor;
                        try self.checkAndAddNeighbor(u, v1);

                        // only try with two when going up
                        if (vf > uf) {
                            for (p1 + 1..mpos) |p2| {
                                const m2 = mbuf[p2];
                                var v2 = v1;
                                v2.fm[m2] = floor;
                                try self.checkAndAddNeighbor(u, v2);
                            }
                        }
                    }

                    // try taking one or two generators
                    for (0..gpos) |p1| {
                        const g1 = gbuf[p1];
                        var v1 = u;
                        v1.fl = floor;
                        v1.fg[g1] = floor;
                        try self.checkAndAddNeighbor(u, v1);

                        // only try with two when going up
                        if (vf > uf) {
                            for (p1 + 1..gpos) |p2| {
                                const g2 = gbuf[p2];
                                var v2 = v1;
                                v2.fg[g2] = floor;
                                try self.checkAndAddNeighbor(u, v2);
                            }
                        }
                    }

                    // try taking a microchip and a generator
                    // only try when going up
                    if (vf > uf) {
                        for (0..xpos) |p| {
                            const c = xbuf[p];
                            var v = u;
                            v.fl = floor;
                            v.fm[c] = floor;
                            v.fg[c] = floor;
                            try self.checkAndAddNeighbor(u, v);
                        }
                    }
                }
            }
            return INFINITY;
        }

        fn checkAndAddNeighbor(self: *AStar, u: State, v: State) !void {
            if (self.seen.contains(v.fingerprint())) return;

            if (!v.isValid()) return;

            var du: usize = INFINITY;
            if (self.distance.get(u)) |d| {
                du = d;
            }
            var dv: usize = INFINITY;
            if (self.distance.get(v)) |d| {
                dv = d;
            }
            const tentative = du + 1;
            if (tentative >= dv) return;

            const delta = tentative + self.floors - v.fl - 1;
            try self.distance.put(v, tentative);
            try self.pending.add(StateDist.init(v, delta));
        }
    };
};

test "sample part 1" {
    const data =
        \\The first floor contains a hydrogen-compatible microchip and a lithium-compatible microchip.
        \\The second floor contains a hydrogen generator.
        \\The third floor contains a lithium generator.
        \\The fourth floor contains nothing relevant.
    ;
    std.debug.print("\n", .{});

    var factory = Factory.init(std.testing.allocator, false);
    defer factory.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try factory.addLine(line);
    }

    const steps = try factory.findShortestSteps();
    const expected = @as(usize, 11);
    try testing.expectEqual(expected, steps);
}
