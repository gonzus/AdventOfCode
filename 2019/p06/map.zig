const std = @import("std");
const assert = std.debug.assert;

pub const Map = struct {
    name_to_pos: std.StringHashMap(usize),
    pos_to_name: [4096][]const u8,
    body_parent: [4096]?usize,
    pos: usize,

    pub fn init() Map {
        var self = Map{
            .name_to_pos = std.StringHashMap(usize).init(std.heap.direct_allocator),
            .pos_to_name = undefined,
            .body_parent = undefined,
            .pos = 0,
        };
        return self;
    }

    pub fn deinit(self: Map) void {
        self.name_to_pos.deinit();
    }

    pub fn add_orbit(self: *Map, str: []const u8) void {
        var it = std.mem.separate(str, ")");
        var parent: ?usize = null;
        while (it.next()) |what| {
            const found = self.name_to_pos.contains(what);
            const gop = self.name_to_pos.getOrPutValue(what, self.pos) catch unreachable;
            const pos = gop.value;
            if (!found) {
                // std.debug.warn("BODY {} => {}\n", what, pos);
                self.body_parent[pos] = null;
                self.pos_to_name[pos] = what;
                self.pos += 1;
            }
            if (parent == null) {
                parent = pos;
            } else {
                const child = pos;
                self.body_parent[child] = parent.?;
                // std.debug.warn("PARENT {} => {}\n", self.pos_to_name[child], self.pos_to_name[parent.?]);
            }
        }
    }

    fn inc_orbit(self: *Map, pos: ?usize, distance: usize) usize {
        if (pos == null) return 0;
        const child = pos.?;
        // std.debug.warn("ORBITS {} {}: +1\n", self.pos_to_name[child], distance);
        const parent = self.body_parent[child];
        return 1 + self.inc_orbit(parent, distance + 1);
    }

    pub fn count_orbits(self: *Map) usize {
        var count: usize = 0;
        var j: usize = 0;
        while (j < self.pos) : (j += 1) {
            const parent = self.body_parent[j];
            count += self.inc_orbit(parent, 0);
        }
        return count;
    }

    pub fn count_hops(self: *Map, a: []const u8, b: []const u8) usize {
        const pa = self.name_to_pos.get(a);
        const pb = self.name_to_pos.get(b);
        var ha = std.AutoHashMap(usize, usize).init(std.heap.direct_allocator);
        defer ha.deinit();

        var current: usize = pa.?.value;
        var count: usize = 0;
        while (true) {
            const parent = self.body_parent[current];
            if (parent == null) break;
            count += 1;
            current = parent.?;
            // std.debug.warn("HOP A {} {}\n", self.pos_to_name[current], count);
            _ = ha.put(current, count) catch unreachable;
        }

        current = pb.?.value;
        count = 0;
        while (true) {
            const parent = self.body_parent[current];
            if (parent == null) break;
            count += 1;
            current = parent.?;
            // std.debug.warn("HOP B {} {}\n", self.pos_to_name[current], count);
            if (ha.contains(current)) {
                count += ha.get(current).?.value;
                break;
            }
        }
        return count - 2;
    }
};

test "total orbit count" {
    const data: []const u8 =
        \\COM)B
        \\B)C
        \\C)D
        \\D)E
        \\E)F
        \\B)G
        \\G)H
        \\D)I
        \\E)J
        \\J)K
        \\K)L
    ;
    var map = Map.init();
    defer map.deinit();

    var it = std.mem.separate(data, "\n");
    while (it.next()) |what| {
        map.add_orbit(what);
    }
    const count = map.count_orbits();
    assert(count == 42);
}

test "hop count" {
    const data: []const u8 =
        \\COM)B
        \\B)C
        \\C)D
        \\D)E
        \\E)F
        \\B)G
        \\G)H
        \\D)I
        \\E)J
        \\J)K
        \\K)L
        \\K)YOU
        \\I)SAN
    ;
    var map = Map.init();
    defer map.deinit();

    var it = std.mem.separate(data, "\n");
    while (it.next()) |what| {
        map.add_orbit(what);
    }
    const count = map.count_hops("YOU", "SAN");
    assert(count == 4);
}
