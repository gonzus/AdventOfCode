const std = @import("std");
const assert = std.debug.assert;

pub const Map = struct {
    name_to_pos: std.StringHashMap(usize),
    body_parent: [4096]i32,
    pos: usize,

    pub fn init() Map {
        var self = Map{
            .name_to_pos = std.StringHashMap(usize).init(std.heap.direct_allocator),
            .body_parent = undefined,
            .pos = 0,
        };
        return self;
    }

    pub fn destroy(self: Map) void {
        self.name_to_pos.deinit();
    }

    pub fn add_orbit(self: *Map, str: []const u8) void {
        var it = std.mem.separate(str, ")");
        var first = true;
        var parent: usize = undefined;
        while (it.next()) |what| {
            const found = self.name_to_pos.contains(what);
            const gop = self.name_to_pos.getOrPutValue(what, self.pos) catch unreachable;
            const pos = gop.value;
            if (!found) {
                // std.debug.warn("BODY {} {}\n", what, pos);
                self.body_parent[pos] = -1;
                self.pos += 1;
            }
            if (first) {
                parent = pos;
            } else {
                const child = pos;
                self.body_parent[child] = @intCast(i32, parent);
                // std.debug.warn("PARENT {} {}\n", child, parent);
            }
            first = false;
        }
    }

    fn inc_orbit(self: *Map, pos: i32, distance: usize) usize {
        if (pos < 0) return 0;
        const child = @intCast(usize, pos);
        // std.debug.warn("ORBITS {} {}: +1\n", child, distance);
        const parent = @intCast(i32, self.body_parent[child]);
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
            if (parent < 0) break;
            count += 1;
            current = @intCast(usize, parent);
            // std.debug.warn("HOP 1 {} {}\n", current, count);
            _ = ha.put(current, count) catch unreachable;
        }

        current = pb.?.value;
        count = 0;
        while (true) {
            const parent = self.body_parent[current];
            if (parent < 0) break;
            count += 1;
            current = @intCast(usize, parent);
            // std.debug.warn("HOP 2 {} {}\n", current, count);
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
    var it = std.mem.separate(data, "\n");
    while (it.next()) |what| {
        map.add_orbit(what);
    }
    const count = map.count_orbits();
    std.debug.warn("Count {}\n", count);
    const expected: usize = 42;
    assert(count == expected);
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
    var it = std.mem.separate(data, "\n");
    while (it.next()) |what| {
        map.add_orbit(what);
    }
    const count = map.count_hops("YOU", "SAN");
    std.debug.warn("Count {}\n", count);
    const expected: usize = 4;
    assert(count == expected);
}
