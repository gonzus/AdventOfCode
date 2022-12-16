const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;
const StringTable = @import("./util/strtab.zig").StringTable;

pub const Cave = struct {
    const Valve = struct {
        name: usize,
        flow: usize,
        neighbors: std.ArrayList(usize),

        pub fn init(name: []const u8, flow: usize, allocator: Allocator, cave: *Cave) Valve {
            const pos = cave.strings.add(name);
            const self = Valve{
                .name = pos,
                .flow = flow,
                .neighbors = std.ArrayList(usize).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Valve) void {
            self.neighbors.deinit();
        }
    };

    const Mask = struct {
        bits: u64,

        pub fn init() Mask {
            return Mask{.bits = 0};
        }

        pub fn is_empty(self: Mask) bool {
            return self.bits == 0;
        }

        pub fn is_set(self: Mask, bit: usize) bool {
            if (bit >= 64) unreachable;
            return (self.bits & (@as(u64, 1) << @intCast(u6, bit))) != 0;
        }

        pub fn set(self: *Mask, bit: usize) void {
            if (bit >= 64) unreachable;
            self.bits |= (@as(u64, 1) << @intCast(u6, bit));
        }

        pub fn clear(self: *Mask, bit: usize) void {
            if (bit >= 64) unreachable;
            self.bits &= ~(@as(u64, 1) << @intCast(u6, bit));
        }

        pub fn count_set(self: Mask) usize {
            return @popCount(self.bits);
        }

        pub fn set_and(self: Mask, other: Mask) Mask {
            return Mask{.bits = (self.bits & other.bits)};
        }
    };

    allocator: Allocator,
    strings: StringTable,
    valves: std.AutoHashMap(usize, Valve),
    cache: std.AutoHashMap(Mask, usize),
    dist: [][]usize,

    pub fn init(allocator: Allocator) Cave {
        var self = Cave{
            .allocator = allocator,
            .strings = StringTable.init(allocator),
            .valves = std.AutoHashMap(usize, Valve).init(allocator),
            .cache = std.AutoHashMap(Mask, usize).init(allocator),
            .dist = undefined,
        };
        return self;
    }

    pub fn deinit(self: *Cave) void {
        for (self.dist) |*row| {
            self.allocator.free(row.*);
        }
        self.allocator.free(self.dist);
        self.cache.deinit();
        var it = self.valves.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.valves.deinit();
        self.strings.deinit();
    }

    pub fn add_line(self: *Cave, line: []const u8) !void {
        var it = std.mem.tokenize(u8, line, " ,;");
        _ = it.next(); // Valve
        const name = it.next().?;
        _ = it.next(); // has
        _ = it.next(); // flow
        var it_rate = std.mem.tokenize(u8, it.next().?, "=");
        _ = it_rate.next(); // rate
        const flow = try std.fmt.parseInt(usize, it_rate.next().?, 10);
        var valve = Valve.init(name, flow, self.allocator, self);
        _ = it.next(); // tunnels
        _ = it.next(); // lead
        _ = it.next(); // to
        _ = it.next(); // valve(s)
        while (it.next()) |what| {
            const pos = self.strings.add(what);
            try valve.neighbors.append(pos);
        }
        try self.valves.put(valve.name, valve);
    }

    pub fn show(self: Cave) void {
        std.debug.print("----------\n", .{});
        var it = self.valves.iterator();
        while (it.next()) |entry| {
            const pos = entry.key_ptr.*;
            const name = self.strings.get_str(pos).?;
            const valve = entry.value_ptr.*;
            std.debug.print("Valve #{} - [{s}] with flow {}:\n", .{pos, name, valve.flow});
            for (valve.neighbors.items) |neighbor| {
                const nt = self.strings.get_str(neighbor).?;
                std.debug.print("  Tunnel to [{s}]\n", .{nt});
            }
        }
    }

    fn floyd_warshall(self: *Cave) !void {
        // allocate and initialize matrix to infinity
        const size = self.valves.count();
        self.dist = try self.allocator.alloc([]usize, size);
        for (self.dist) |*row| {
            row.* = try self.allocator.alloc(usize, size);
            for (row.*) |*d| {
                d.* = std.math.maxInt(usize);
            }
        }

        // add zero distances between each vertex and itself
        // add real distances for existing vertexes
        var itv = self.valves.iterator();
        while (itv.next()) |ev| {
            const src = ev.value_ptr.*;
            self.dist[src.name][src.name] = 0;

            for (src.neighbors.items) |tunnel| {
                self.dist[src.name][tunnel] = 1;
            }
        }

        // compute shortest distances between all pairs of vertexes
        var k: usize = 0;
        while (k < size) : (k += 1) {
            var i: usize = 0;
            while (i < size) : (i += 1) {
                var j: usize = 0;
                while (j < size) : (j += 1) {
                    if (self.dist[i][k] == std.math.maxInt(usize)) continue;
                    if (self.dist[k][j] == std.math.maxInt(usize)) continue;
                    const d = self.dist[i][k] + self.dist[k][j];
                    if (self.dist[i][j] > d) self.dist[i][j] = d;
                }
            }
        }
    }

    fn visit_and_open_valves(self: *Cave, pos: usize, budget: usize, state: Mask, flow: usize) !void {
        var result = try self.cache.getOrPut(state);
        if (!result.found_existing) {
            result.value_ptr.* = 0;
        }
        if (result.value_ptr.* < flow) result.value_ptr.* = flow;

        var itv = self.valves.iterator();
        while (itv.next()) |ev| {
            const valve = ev.value_ptr.*;
            const nxt = valve.name;
            if (valve.flow <= 0) continue; // valve has no flow

            if (state.is_set(nxt)) continue; // valve is already open

            var delta = self.dist[pos][nxt] + 1; // time to move and open
            if (budget <= delta) continue; // not enough time

            // all good, recurse and keep looking
            var new_budget = budget - delta;
            var new_flow = flow + new_budget * valve.flow;
            var new_state = state;
            new_state.set(nxt);
            try self.visit_and_open_valves(nxt, new_budget, new_state, new_flow);
        }
    }

    pub fn find_best(self: *Cave, budget: usize, actors: usize) !usize {
        // compute shortest distances for all pairs of valves
        try self.floyd_warshall();

        // clear our internal cache
        self.cache.clearRetainingCapacity();

        // start visiting at node AA
        const pos = self.strings.get_pos("AA").?;
        const state = Mask.init();
        try self.visit_and_open_valves(pos, budget, state, 0);

        var best: usize = 0;
        if (actors == 1) {
            // for one actor, the best flow is the answer
            var it = self.cache.iterator();
            while (it.next()) |e| {
                if (best < e.value_ptr.*) best = e.value_ptr.*;
            }
        }
        if (actors == 2) {
            // for two actors, we look for pairs of solutions that
            // have no overlapping open valves, and add them;
            // we remember the best such pair
            var it1 = self.cache.iterator();
            while (it1.next()) |e1| {
                const m1 = e1.key_ptr.*;
                var it2 = self.cache.iterator();
                while (it2.next()) |e2| {
                    const m2 = e2.key_ptr.*;
                    if (!m1.set_and(m2).is_empty()) continue;
                    const flow = e1.value_ptr.* + e2.value_ptr.*;
                    if (best < flow) best = flow;
                }
            }
        }
        return best;
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\Valve AA has flow rate=0; tunnels lead to valves DD, II, BB
        \\Valve BB has flow rate=13; tunnels lead to valves CC, AA
        \\Valve CC has flow rate=2; tunnels lead to valves DD, BB
        \\Valve DD has flow rate=20; tunnels lead to valves CC, AA, EE
        \\Valve EE has flow rate=3; tunnels lead to valves FF, DD
        \\Valve FF has flow rate=0; tunnels lead to valves EE, GG
        \\Valve GG has flow rate=0; tunnels lead to valves FF, HH
        \\Valve HH has flow rate=22; tunnel leads to valve GG
        \\Valve II has flow rate=0; tunnels lead to valves AA, JJ
        \\Valve JJ has flow rate=21; tunnel leads to valve II
    ;

    var cave = Cave.init(std.testing.allocator);
    defer cave.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cave.add_line(line);
    }
    // cave.show();
    const best = try cave.find_best(30, 1);

    // const best = try cave.find_best(30);
    try testing.expectEqual(@as(usize, 1651), best);
}

test "sample part 2" {
    const data: []const u8 =
        \\Valve AA has flow rate=0; tunnels lead to valves DD, II, BB
        \\Valve BB has flow rate=13; tunnels lead to valves CC, AA
        \\Valve CC has flow rate=2; tunnels lead to valves DD, BB
        \\Valve DD has flow rate=20; tunnels lead to valves CC, AA, EE
        \\Valve EE has flow rate=3; tunnels lead to valves FF, DD
        \\Valve FF has flow rate=0; tunnels lead to valves EE, GG
        \\Valve GG has flow rate=0; tunnels lead to valves FF, HH
        \\Valve HH has flow rate=22; tunnel leads to valve GG
        \\Valve II has flow rate=0; tunnels lead to valves AA, JJ
        \\Valve JJ has flow rate=21; tunnel leads to valve II
    ;

    var cave = Cave.init(std.testing.allocator);
    defer cave.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cave.add_line(line);
    }
    // cave.show();
    const best = try cave.find_best(26, 2);

    try testing.expectEqual(@as(usize, 1707), best);
}
