const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;
const DoubleEndedQueue = @import("./util/queue.zig").DoubleEndedQueue;
const Math = @import("./util/math.zig").Math;
const UtilGrid = @import("./util/grid.zig");

const Allocator = std.mem.Allocator;

pub const Vault = struct {
    const StringId = StringTable.StringId;
    const Pos = UtilGrid.Pos;
    const Grid = UtilGrid.SparseGrid(Tile);
    const Score = std.AutoHashMap(Pos, usize);
    const INFINITY = std.math.maxInt(u32);
    const OFFSET = 500;

    pub const Dir = enum(u8) {
        N = 1,
        S = 2,
        W = 3,
        E = 4,

        pub fn move(pos: Pos, dir: Dir) Pos {
            var nxt = pos;
            switch (dir) {
                .N => nxt.y -= 1,
                .S => nxt.y += 1,
                .W => nxt.x -= 1,
                .E => nxt.x += 1,
            }
            return nxt;
        }

        pub fn format(
            dir: Dir,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("{s}", .{@tagName(dir)});
        }
    };
    const Dirs = std.meta.tags(Dir);

    pub const Tile = enum(u8) {
        empty = ' ',
        wall = '#',
        door = 'D',
        key = 'K',

        pub fn format(
            tile: Tile,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("{c}", .{@intFromEnum(tile)});
        }
    };

    allocator: Allocator,
    grid: Grid,
    rows: usize,
    cols: usize,
    keys: std.AutoHashMap(Pos, u8),
    doors: std.AutoHashMap(Pos, u8),
    start: Pos,
    key_paths: KeyPaths,

    pub fn init(allocator: Allocator) Vault {
        return .{
            .allocator = allocator,
            .grid = Grid.init(allocator, .empty),
            .rows = 0,
            .cols = 0,
            .keys = std.AutoHashMap(Pos, u8).init(allocator),
            .doors = std.AutoHashMap(Pos, u8).init(allocator),
            .start = undefined,
            .key_paths = KeyPaths.init(allocator),
        };
    }

    pub fn deinit(self: *Vault) void {
        self.doors.deinit();
        self.keys.deinit();
        self.grid.deinit();
        self.key_paths.deinit();
    }

    pub fn show(self: Vault) void {
        std.debug.print("MAP: {} x {} - {} {} - {} {}\n", .{
            self.grid.max.x - self.grid.min.x + 1,
            self.grid.max.y - self.grid.min.y + 1,
            self.grid.min.x,
            self.grid.min.y,
            self.grid.max.x,
            self.grid.max.y,
        });
        var y: isize = self.grid.min.y;
        while (y <= self.grid.max.y) : (y += 1) {
            const uy: usize = @intCast(y);
            std.debug.print("{:>4} | ", .{uy});
            var x: isize = self.grid.min.x;
            while (x <= self.grid.max.x) : (x += 1) {
                const pos = Pos.init(x, y);
                const kind = self.grid.get(pos);
                var label: u8 = switch (kind) {
                    .empty => '.',
                    .wall => '#',
                    .door => self.doors.get(pos).?,
                    .key => self.keys.get(pos).?,
                };
                if (pos.equal(self.start)) {
                    label = '@';
                }
                std.debug.print("{c}", .{label});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn addLine(self: *Vault, line: []const u8) !void {
        for (0..line.len) |x| {
            const p = Pos.initFromUnsigned(x, self.rows);
            var t: Tile = .empty;
            switch (line[x]) {
                '#' => t = .wall,
                '@' => self.start = p,
                'A'...'Z' => {
                    t = .door;
                    _ = try self.doors.put(p, line[x]);
                },
                'a'...'z' => {
                    t = .key;
                    _ = try self.keys.put(p, line[x]);
                },
                else => {},
            }
            try self.grid.set(p, t);
        }
        self.rows += 1;
    }

    const Path = struct {
        steps: usize,
        doors: u32,
        pos: Pos,

        pub fn init(steps: usize, doors: u32, pos: Pos) Path {
            return .{
                .steps = steps,
                .doors = doors,
                .pos = pos,
            };
        }

        fn cmp(_: void, l: Path, r: Path) std.math.Order {
            if (l.steps < r.steps) return .lt;
            if (l.steps > r.steps) return .gt;
            if (l.doors < r.doors) return .lt;
            if (l.doors > r.doors) return .gt;
            return Pos.cmp({}, l.pos, r.pos);
        }
    };

    const KeyPaths = struct {
        keys: std.AutoHashMap(u8, u8),
        paths: std.AutoHashMap(u16, Path),

        pub fn init(allocator: Allocator) KeyPaths {
            return .{
                .paths = std.AutoHashMap(u16, Path).init(allocator),
                .keys = std.AutoHashMap(u8, u8).init(allocator),
            };
        }

        pub fn deinit(self: *KeyPaths) void {
            self.keys.deinit();
            self.paths.deinit();
        }

        pub fn addPath(self: *KeyPaths, src: u8, tgt: u8, path: Path) !void {
            // src, tgt can be 'a'..'z' => keys
            // src, tgt can be '0'..'9' => starts
            try self.keys.put(src, tgt);
            var key: u16 = 0;
            key |= src;
            key <<= 8;
            key |= tgt;
            try self.paths.put(key, path);
        }

        pub fn clear(self: *KeyPaths) void {
            self.paths.clearRetainingCapacity();
            self.keys.clearRetainingCapacity();
        }

        pub fn pathFound(self: *KeyPaths, src: u8, tgt: u8) bool {
            var key: u16 = 0;
            key |= src;
            key <<= 8;
            key |= tgt;
            return self.paths.contains(key);
        }

        pub fn show(self: KeyPaths) void {
            std.debug.print("KeyPaths: {}\n", .{self.paths.count()});
            var it = self.paths.iterator();
            while (it.next()) |e| {
                const key = e.key_ptr.*;
                const src: u8 = @intCast(key >> 8);
                const tgt: u8 = @intCast(key & 0xff);
                const path = e.value_ptr.*;
                std.debug.print("  path {c} {c}: {} steps, crossing doors", .{ src, tgt, path.steps });
                for (0..26) |p| {
                    const shift: u5 = @intCast(p);
                    const mask = @as(u32, 1) << shift;
                    if (path.doors & mask == 0) continue;
                    var label: u8 = 'A';
                    label += @intCast(p);
                    std.debug.print(" {c}", .{label});
                }
                std.debug.print("\n", .{});
            }
        }
    };

    fn findShortestPath(self: *Vault, src: Pos, tgt: Pos) !Path {
        // std.debug.print("Shortest path {} {}\n", .{ src, tgt });
        var visited = std.AutoHashMap(Pos, void).init(self.allocator);
        defer visited.deinit();

        const PQ = std.PriorityQueue(Path, void, Path.cmp);
        var queue = PQ.init(self.allocator, {});
        defer queue.deinit();

        _ = try queue.add(Path.init(0, 0, src));
        while (queue.count() != 0) {
            var path = queue.remove();
            if (path.pos.equal(tgt)) {
                // std.debug.print("Shortest path {} {} => {} steps\n", .{ src, tgt, path.steps });
                return path;
            }
            var doors = path.doors; // make a copy
            if (self.doors.get(path.pos)) |door| {
                if (std.ascii.isUpper(door)) {
                    // std.debug.print("Door {c}\n", .{door});
                    const shift: u3 = @intCast(std.ascii.toLower(door) - 'a');
                    doors |= @as(u8, 1) << shift;
                }
            }
            try visited.put(path.pos, {});
            for (Dirs) |d| {
                const nxt = Dir.move(path.pos, d);
                if (visited.contains(nxt)) continue;
                if (self.grid.get(nxt) == .wall) continue;
                _ = try queue.add(Path.init(path.steps + 1, doors, nxt));
            }
        }
        return Path.init(INFINITY, 0, src);
    }

    fn findKeyPaths(self: *Vault, starts: []const Pos) !void {
        self.key_paths.clear();
        for (starts) |start_pos| {
            const start = self.doors.get(start_pos).?;
            var its = self.keys.iterator();
            while (its.next()) |es| {
                const src = es.value_ptr.*;
                const src_pos = es.key_ptr.*;
                const pss = try self.findShortestPath(start_pos, src_pos);
                if (pss.steps != INFINITY) {
                    try self.key_paths.addPath(start, src, pss);
                }
                var itt = self.keys.iterator();
                while (itt.next()) |et| {
                    const tgt = et.value_ptr.*;
                    if (tgt == src) continue;
                    if (self.key_paths.pathFound(tgt, src)) continue;
                    const tgt_pos = et.key_ptr.*;
                    const pst = try self.findShortestPath(src_pos, tgt_pos);
                    if (pst.steps != INFINITY) {
                        try self.key_paths.addPath(src, tgt, pst);
                        try self.key_paths.addPath(tgt, src, pst);
                    }
                }
            }
        }
        self.show();
        self.key_paths.show();
    }

    fn alterGrid(self: *Vault, starts: *[4]Pos) !void {
        try self.grid.set(self.start, .wall);
        for (Dirs) |d| {
            const nxt = Dir.move(self.start, d);
            try self.grid.set(nxt, .wall);
        }
        {
            const p = Pos.init(self.start.x + 1, self.start.y - 1);
            try self.grid.set(p, .door);
            _ = try self.doors.put(p, '0');
            starts[0] = p;
        }
        {
            const p = Pos.init(self.start.x + 1, self.start.y + 1);
            try self.grid.set(p, .door);
            _ = try self.doors.put(p, '1');
            starts[1] = p;
        }
        {
            const p = Pos.init(self.start.x - 1, self.start.y + 1);
            try self.grid.set(p, .door);
            _ = try self.doors.put(p, '2');
            starts[2] = p;
        }
        {
            const p = Pos.init(self.start.x - 1, self.start.y - 1);
            try self.grid.set(p, .door);
            _ = try self.doors.put(p, '3');
            starts[3] = p;
        }

        self.start = Pos.init(999999, 999999);
    }

    fn findKeys(self: *Vault, starts: []const Pos) !void {
        _ = self;
        _ = starts;
    }

    fn findKeysDefault(self: *Vault, starts: []const Pos) !void {
        _ = self;
        _ = starts;
    }

    pub fn collectAllKeys(self: *Vault) !usize {
        var starts: [4]Pos = undefined;
        try self.alterGrid(&starts);
        for (starts) |s| {
            std.debug.print("Start: {}\n", .{s});
        }
        try self.findKeyPaths(&starts);
        self.show();
        return 0;
    }
};

// test "sample part 1 case A" {
//     const data: []const u8 =
//         \\#########
//         \\#b.A.@.a#
//         \\#########
//     ;
//
//     var vault = Vault.init(testing.allocator);
//     defer vault.deinit();
//
//     var it = std.mem.split(u8, data, "\n");
//     while (it.next()) |line| {
//         try vault.addLine(line);
//     }
//
//     const result = try vault.collectAllKeys();
//     const expected = @as(usize, 8);
//     try testing.expectEqual(expected, result);
// }
//
// test "sample part 1 case B" {
//     const data: []const u8 =
//         \\########################
//         \\#f.D.E.e.C.b.A.@.a.B.c.#
//         \\######################.#
//         \\#d.....................#
//         \\########################
//     ;
//
//     var vault = Vault.init(testing.allocator);
//     defer vault.deinit();
//
//     var it = std.mem.split(u8, data, "\n");
//     while (it.next()) |line| {
//         try vault.addLine(line);
//     }
//
//     const result = try vault.collectAllKeys();
//     const expected = @as(usize, 86);
//     try testing.expectEqual(expected, result);
// }
//
// test "sample part 1 case C" {
//     const data: []const u8 =
//         \\########################
//         \\#...............b.C.D.f#
//         \\#.######################
//         \\#.....@.a.B.c.d.A.e.F.g#
//         \\########################
//     ;
//
//     var vault = Vault.init(testing.allocator);
//     defer vault.deinit();
//
//     var it = std.mem.split(u8, data, "\n");
//     while (it.next()) |line| {
//         try vault.addLine(line);
//     }
//
//     const result = try vault.collectAllKeys();
//     const expected = @as(usize, 132);
//     try testing.expectEqual(expected, result);
// }

test "sample part 1 case D" {
    const data: []const u8 =
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

    var vault = Vault.init(testing.allocator);
    defer vault.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try vault.addLine(line);
    }

    const result = try vault.collectAllKeys();
    const expected = @as(usize, 136);
    try testing.expectEqual(expected, result);
}

// test "sample part 1 case E" {
//     const data: []const u8 =
//         \\########################
//         \\#@..............ac.GI.b#
//         \\###d#e#f################
//         \\###A#B#C################
//         \\###g#h#i################
//         \\########################
//     ;
//
//     var vault = Vault.init(testing.allocator);
//     defer vault.deinit();
//
//     var it = std.mem.split(u8, data, "\n");
//     while (it.next()) |line| {
//         try vault.addLine(line);
//     }
//
//     const result = try vault.collectAllKeys();
//     const expected = @as(usize, 81);
//     try testing.expectEqual(expected, result);
// }
