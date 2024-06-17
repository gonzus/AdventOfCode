const std = @import("std");
const testing = std.testing;
const DoubleEndedQueue = @import("./util/queue.zig").DoubleEndedQueue;
const Math = @import("./util/math.zig").Math;
const UtilGrid = @import("./util/grid.zig");

const Allocator = std.mem.Allocator;

pub const Vault = struct {
    const Pos = UtilGrid.Pos;
    const Grid = UtilGrid.SparseGrid(Tile);
    const Score = std.AutoHashMap(Pos, usize);
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

    pub const Node = struct {
        pos: Pos,
        mask: usize,
        gonzo: std.AutoHashMap(u64, void),

        pub fn init(allocator: Allocator, pos: Pos, mask: usize) Node {
            return Node{
                .pos = pos,
                .mask = mask,
                .gonzo = std.AutoHashMap(u64, void).init(allocator),
            };
        }

        pub fn deinit(self: *Node) void {
            self.gonzo.deinit();
        }

        pub fn encode(self: Node) u64 {
            var code: u64 = 0;
            code += self.mask;
            code *= 1000;
            code += @intCast(self.pos.x);
            code *= 1000;
            code += @intCast(self.pos.y);
            return code;
        }

        pub fn get_mask(label: u64) usize {
            return label / 1000000;
        }

        fn cmp(_: void, l: Node, r: Node) std.math.Order {
            if (l.mask < r.mask) return std.math.Order.lt;
            if (l.mask > r.mask) return std.math.Order.gt;
            return Pos.cmp({}, l.pos, r.pos);
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

        fn cmp(_: void, l: NodeInfo, r: NodeInfo) std.math.Order {
            if (l.dist < r.dist) return std.math.Order.lt;
            if (l.dist > r.dist) return std.math.Order.gt;
            if (l.label < r.label) return std.math.Order.lt;
            if (l.label > r.label) return std.math.Order.gt;
            return std.math.Order.eq;
        }
    };

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
    nodes: std.AutoHashMap(u64, Node),
    pos_current: Pos,

    pub fn init(allocator: Allocator) Vault {
        return .{
            .allocator = allocator,
            .grid = Grid.init(allocator, .empty),
            .rows = 0,
            .cols = 0,
            .keys = std.AutoHashMap(Pos, u8).init(allocator),
            .doors = std.AutoHashMap(Pos, u8).init(allocator),
            .nodes = std.AutoHashMap(u64, Node).init(allocator),
            .pos_current = Pos.init(OFFSET / 2, OFFSET / 2),
        };
    }

    pub fn deinit(self: *Vault) void {
        var it = self.nodes.valueIterator();
        while (it.next()) |node| {
            node.*.deinit();
        }
        self.nodes.deinit();
        self.doors.deinit();
        self.keys.deinit();
        self.grid.deinit();
    }

    // pub fn show(self: Vault) void {
    //     std.debug.print("MAP: {} x {} - {} {} - {} {} - Oxygen at {}\n", .{
    //         self.grid.max.x - self.grid.min.x + 1,
    //         self.grid.max.y - self.grid.min.y + 1,
    //         self.grid.min.x,
    //         self.grid.min.y,
    //         self.grid.max.x,
    //         self.grid.max.y,
    //         self.pos_oxygen,
    //     });
    //     var y: isize = self.grid.min.y;
    //     while (y <= self.grid.max.y) : (y += 1) {
    //         const uy: usize = @intCast(y);
    //         std.debug.print("{:>4} | ", .{uy});
    //         var x: isize = self.grid.min.x;
    //         while (x <= self.grid.max.x) : (x += 1) {
    //             const pos = Pos.init(x, y);
    //             var label: u8 = @intFromEnum(self.grid.get(pos));
    //             if (pos.equal(self.pos_oxygen)) {
    //                 label = 'O';
    //             }
    //             if (pos.equal(self.pos_current)) {
    //                 label = 'D';
    //             }
    //             std.debug.print("{c}", .{label});
    //         }
    //         std.debug.print("\n", .{});
    //     }
    // }

    pub fn addLine(self: *Vault, line: []const u8) !void {
        for (0..line.len) |x| {
            const p = Pos.initFromUnsigned(x, self.rows);
            var t: Tile = .empty;
            switch (line[x]) {
                '#' => t = .wall,
                '@' => self.pos_current = p,
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

    pub fn collectAllKeys(self: *Vault) !usize {
        self.walk_map();
        return self.walk_graph();
    }

    pub fn walk_map(self: *Vault) void {
        // _ = self.get_all_keys();
        self.nodes.clearRetainingCapacity();

        const PQ = std.PriorityQueue(Node, void, Node.cmp);
        var Pend = PQ.init(self.allocator, {});
        defer Pend.deinit();

        // We start from the oxygen system position, which has already been filled with oxygen
        const first = Node.init(self.allocator, self.pos_current, 0);
        _ = Pend.add(first) catch unreachable;
        while (Pend.count() != 0) {
            var curr = Pend.remove();
            if (self.nodes.contains(curr.encode())) continue;
            if (curr.mask == self.get_all_keys()) continue;

            for (Dirs) |d| {
                const v = Dir.move(curr.pos, d);
                const tile = self.grid.get(v);
                var next: ?Node = null;
                switch (tile) {
                    .wall => {},
                    .empty => {
                        next = Node.init(self.allocator, v, curr.mask);
                    },
                    .key => {
                        const shift: u5 = @as(u5, @intCast(self.keys.get(v).? - 'a'));
                        const needed: usize = @shlExact(@as(usize, @intCast(1)), shift);
                        next = Node.init(self.allocator, v, curr.mask | needed);
                    },
                    .door => {
                        if (!self.doors.contains(v)) {
                            next = Node.init(self.allocator, v, curr.mask);
                        } else {
                            const shift: u5 = @as(u5, @intCast(self.doors.get(v).? - 'A'));
                            const needed: usize = @shlExact(@as(usize, @intCast(1)), shift);
                            if (curr.mask & needed != 0) {
                                next = Node.init(self.allocator, v, curr.mask);
                            }
                        }
                    },
                }
                if (next == null) continue;
                const n = next.?;
                const e = n.encode();
                _ = curr.gonzo.put(e, {}) catch unreachable;
                if (self.nodes.contains(e)) continue;
                _ = Pend.add(n) catch unreachable;
            }
            _ = self.nodes.put(curr.encode(), curr) catch unreachable;
        }
        // std.debug.warn("Graph has {} nodes\n", self.nodes.count());
    }

    pub fn walk_graph(self: *Vault) usize {
        var seen = std.AutoHashMap(u64, void).init(self.allocator);
        defer seen.deinit();

        const PQ = std.PriorityQueue(NodeInfo, void, NodeInfo.cmp);
        var Pend = PQ.init(self.allocator, {});
        defer Pend.deinit();

        const all_keys = self.get_all_keys();

        var dmax: usize = 0;
        const home = Node.init(self.allocator, self.pos_current, 0);
        const first = NodeInfo.init(home.encode(), 0);
        _ = Pend.add(first) catch unreachable;
        while (Pend.count() != 0) {
            const data = Pend.remove();
            _ = Node.get_mask(data.label);
            if (dmax < data.dist) dmax = data.dist;
            if (Node.get_mask(data.label) == all_keys) break;
            const node = self.nodes.get(data.label).?;
            const dist = data.dist + 1;
            var it = node.gonzo.iterator();
            while (it.next()) |kv| {
                const l = kv.key_ptr.*;
                if (seen.contains(l)) continue;
                _ = seen.put(l, {}) catch unreachable;
                _ = Pend.add(NodeInfo.init(l, dist)) catch unreachable;
            }
        }
        return dmax;
    }

    fn get_all_keys(self: Vault) usize {
        var all_keys: usize = 0;
        var it = self.keys.valueIterator();
        while (it.next()) |key| {
            const shift: u5 = @as(u5, @intCast(key.* - 'a'));
            const mask: usize = @shlExact(@as(usize, @intCast(1)), shift);
            all_keys |= mask;
        }
        return all_keys;
    }
};

test "sample part 1 case A" {
    const data: []const u8 =
        \\#########
        \\#b.A.@.a#
        \\#########
    ;

    var vault = Vault.init(testing.allocator);
    defer vault.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try vault.addLine(line);
    }

    const result = try vault.collectAllKeys();
    const expected = @as(usize, 8);
    try testing.expectEqual(expected, result);
}

test "sample part 1 case B" {
    const data: []const u8 =
        \\########################
        \\#f.D.E.e.C.b.A.@.a.B.c.#
        \\######################.#
        \\#d.....................#
        \\########################
    ;

    var vault = Vault.init(testing.allocator);
    defer vault.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try vault.addLine(line);
    }

    const result = try vault.collectAllKeys();
    const expected = @as(usize, 86);
    try testing.expectEqual(expected, result);
}

test "sample part 1 case C" {
    const data: []const u8 =
        \\########################
        \\#...............b.C.D.f#
        \\#.######################
        \\#.....@.a.B.c.d.A.e.F.g#
        \\########################
    ;

    var vault = Vault.init(testing.allocator);
    defer vault.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try vault.addLine(line);
    }

    const result = try vault.collectAllKeys();
    const expected = @as(usize, 132);
    try testing.expectEqual(expected, result);
}

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

test "sample part 1 case E" {
    const data: []const u8 =
        \\########################
        \\#@..............ac.GI.b#
        \\###d#e#f################
        \\###A#B#C################
        \\###g#h#i################
        \\########################
    ;

    var vault = Vault.init(testing.allocator);
    defer vault.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try vault.addLine(line);
    }

    const result = try vault.collectAllKeys();
    const expected = @as(usize, 81);
    try testing.expectEqual(expected, result);
}
