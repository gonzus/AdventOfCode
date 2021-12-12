const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;
const StringTable = @import("./strtab.zig").StringTable;

pub const Map = struct {
    const Caves = std.ArrayList(usize);

    slack: bool,
    caves: StringTable,
    neighbors: std.AutoHashMap(usize, *Caves),
    seen: std.AutoHashMap(usize, bool),
    paths: StringTable,

    pub fn init(slack: bool) Map {
        var self = Map{
            .slack = slack,
            .caves = StringTable.init(allocator),
            .neighbors = std.AutoHashMap(usize, *Caves).init(allocator),
            .seen = std.AutoHashMap(usize, bool).init(allocator),
            .paths = StringTable.init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.paths.deinit();
        self.seen.deinit();
        var it = self.neighbors.iterator();
        while (it.next()) |entry| {
            var caves = entry.value_ptr.*;
            caves.*.deinit();
            allocator.destroy(caves);
        }
        self.neighbors.deinit();
        self.caves.deinit();
    }

    pub fn process_line(self: *Map, data: []const u8) !void {
        var pos: usize = 0;
        var from: usize = 0;
        var it = std.mem.split(u8, data, "-");
        while (it.next()) |name| : (pos += 1) {
            const id = self.caves.add(name);
            if (pos == 0) {
                from = id;
                continue;
            }
            if (pos == 1) {
                try self.add_path(from, id);
                try self.add_path(id, from);
                continue;
            }
            unreachable;
        }
    }

    pub fn count_total_paths(self: *Map) usize {
        const start = self.caves.get_pos("start") orelse unreachable;
        const end = self.caves.get_pos("end") orelse unreachable;
        self.seen.put(start, true) catch unreachable;
        var path: Caves = Caves.init(allocator);
        defer path.deinit();
        self.walk_caves(0, start, end, &path);

        const count = self.paths.size();
        // std.debug.warn("FOUND {} paths\n", .{count});
        return count;
    }

    fn add_path(self: *Map, from: usize, to: usize) !void {
        // std.debug.warn("Adding path from {} => {}\n", .{ from, to });
        var caves: *Caves = undefined;
        var entry = self.neighbors.getEntry(from);
        if (entry) |e| {
            caves = e.value_ptr.*;
        } else {
            caves = try allocator.create(Caves);
            caves.* = Caves.init(allocator);
            try self.neighbors.put(from, caves);
        }
        try caves.*.append(to);
    }

    fn cave_is_large(self: Map, cave: usize) bool {
        const name = self.caves.get_str(cave) orelse unreachable;
        return name[0] >= 'A' and name[0] <= 'Z';
    }

    fn walk_caves(self: *Map, depth: usize, current: usize, end: usize, path: *Caves) void {
        if (current == end) {
            self.remember_path(path);
            return;
        }
        var neighbors = self.neighbors.get(current) orelse return;
        for (neighbors.items) |n| {
            if (self.cave_is_large(n)) {
                // cave is large, visit without marking as seen
                path.*.append(n) catch unreachable;
                self.walk_caves(depth + 1, n, end, path);
                _ = path.*.pop();
                continue;
            }

            const visited: bool = self.seen.get(n) orelse false;
            if (visited) continue;

            if (self.slack) {
                // not used slack yet; use it and visit without marking as seen
                self.slack = false;
                path.*.append(n) catch unreachable;
                self.walk_caves(depth + 1, n, end, path);
                _ = path.*.pop();
                self.slack = true;
            }

            // visit marking as seen
            self.seen.put(n, true) catch unreachable;
            path.*.append(n) catch unreachable;
            self.walk_caves(depth + 1, n, end, path);
            _ = path.*.pop();
            self.seen.put(n, false) catch unreachable;
        }
    }

    fn remember_path(self: *Map, path: *Caves) void {
        var buf: [10240]u8 = undefined;
        var pos: usize = 0;
        for (path.*.items) |c| {
            if (pos > 0) {
                buf[pos] = ':';
                pos += 1;
            }
            // yeah, the index for each cave ends up reversed in the string, but it is still unique...
            var x: usize = c;
            while (true) {
                const d: u8 = @intCast(u8, x % 10);
                x /= 10;
                buf[pos] = d + '0';
                pos += 1;
                if (x == 0) break;
            }
        }
        // std.debug.warn("REMEMBERING [{s}]\n", .{buf[0..pos]});
        _ = self.paths.add(buf[0..pos]);
    }
};

test "sample part a 1" {
    const data: []const u8 =
        \\start-A
        \\start-b
        \\A-c
        \\A-b
        \\b-d
        \\A-end
        \\b-end
    ;

    var map = Map.init(false);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    const total_paths = map.count_total_paths();
    try testing.expect(total_paths == 10);
}

test "sample part a 2" {
    const data: []const u8 =
        \\dc-end
        \\HN-start
        \\start-kj
        \\dc-start
        \\dc-HN
        \\LN-dc
        \\HN-end
        \\kj-sa
        \\kj-HN
        \\kj-dc
    ;

    var map = Map.init(false);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    const total_paths = map.count_total_paths();
    try testing.expect(total_paths == 19);
}

test "sample part a 3" {
    const data: []const u8 =
        \\fs-end
        \\he-DX
        \\fs-he
        \\start-DX
        \\pj-DX
        \\end-zg
        \\zg-sl
        \\zg-pj
        \\pj-he
        \\RW-he
        \\fs-DX
        \\pj-RW
        \\zg-RW
        \\start-pj
        \\he-WI
        \\zg-he
        \\pj-fs
        \\start-RW
    ;

    var map = Map.init(false);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    const total_paths = map.count_total_paths();
    try testing.expect(total_paths == 226);
}

test "sample part b 1" {
    const data: []const u8 =
        \\start-A
        \\start-b
        \\A-c
        \\A-b
        \\b-d
        \\A-end
        \\b-end
    ;

    var map = Map.init(true);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    const total_paths = map.count_total_paths();
    try testing.expect(total_paths == 36);
}

test "sample part b 2" {
    const data: []const u8 =
        \\dc-end
        \\HN-start
        \\start-kj
        \\dc-start
        \\dc-HN
        \\LN-dc
        \\HN-end
        \\kj-sa
        \\kj-HN
        \\kj-dc
    ;

    var map = Map.init(true);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    const total_paths = map.count_total_paths();
    try testing.expect(total_paths == 103);
}

test "sample part b 3" {
    const data: []const u8 =
        \\fs-end
        \\he-DX
        \\fs-he
        \\start-DX
        \\pj-DX
        \\end-zg
        \\zg-sl
        \\zg-pj
        \\pj-he
        \\RW-he
        \\fs-DX
        \\pj-RW
        \\zg-RW
        \\start-pj
        \\he-WI
        \\zg-he
        \\pj-fs
        \\start-RW
    ;

    var map = Map.init(true);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    const total_paths = map.count_total_paths();
    try testing.expect(total_paths == 3509);
}
