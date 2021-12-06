const std = @import("std");
const assert = std.debug.assert;
const StringTable = @import("./strtab.zig").StringTable;

const allocator = std.testing.allocator;

pub const Map = struct {
    bodies: StringTable,
    parent: [4096]?usize,

    pub fn init() Map {
        var self = Map{
            .bodies = StringTable.init(allocator),
            .parent = undefined,
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.bodies.deinit();
    }

    pub fn add_orbit(self: *Map, str: []const u8) void {
        var it = std.mem.split(u8, str, ")");
        var parent: ?usize = null;
        while (it.next()) |what| {
            var pos: usize = 0;
            if (self.bodies.contains(what)) {
                pos = self.bodies.get_pos(what).?;
            } else {
                pos = self.bodies.add(what);
                self.parent[pos] = null;
            }
            if (parent == null) {
                parent = pos;
            } else {
                const child = pos;
                self.parent[child] = parent.?;
                // std.debug.warn("PARENT {s} => {s}\n", .{ self.bodies.get_str(child), self.bodies.get_str(parent.?) });
            }
        }
    }

    fn inc_orbit(self: *Map, pos: ?usize, distance: usize) usize {
        if (pos == null) return 0;
        const child = pos.?;
        // std.debug.warn("ORBITS {s} {}: +1\n", .{ self.bodies.get_str(child), distance });
        const parent = self.parent[child];
        return 1 + self.inc_orbit(parent, distance + 1);
    }

    pub fn count_orbits(self: *Map) usize {
        var count: usize = 0;
        var j: usize = 0;
        while (j < self.bodies.size()) : (j += 1) {
            const parent = self.parent[j];
            count += self.inc_orbit(parent, 0);
        }
        return count;
    }

    pub fn count_hops(self: *Map, a: []const u8, b: []const u8) usize {
        var current: usize = self.bodies.get_pos(a).?;
        var ha = std.AutoHashMap(usize, usize).init(allocator);
        defer ha.deinit();

        var count: usize = 0;
        while (true) {
            const parent = self.parent[current];
            if (parent == null) break;
            count += 1;
            current = parent.?;
            // std.debug.warn("HOP A {s} {}\n", .{ self.bodies.get_str(current), count });
            _ = ha.put(current, count) catch unreachable;
        }

        current = self.bodies.get_pos(b).?;
        count = 0;
        while (true) {
            const parent = self.parent[current];
            if (parent == null) break;
            count += 1;
            current = parent.?;
            // std.debug.warn("HOP B {s} {}\n", .{ self.bodies.get_str(current), count });
            if (ha.contains(current)) {
                count += ha.getEntry(current).?.value_ptr.*;
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

    var it = std.mem.split(u8, data, "\n");
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

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |what| {
        map.add_orbit(what);
    }
    const count = map.count_hops("YOU", "SAN");
    assert(count == 4);
}
