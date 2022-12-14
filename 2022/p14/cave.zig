const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Pos = struct {
    x: isize,
    y: isize,

    pub fn init(x: isize, y: isize) Pos {
        return Pos{.x = x, .y = y};
    }
};

pub const Cave = struct {
    const Cell = enum(u8) {
        Source = '+',
        Empty  = '.',
        Rock   = '#',
        Sand   = 'o',
    };

    grid: std.AutoHashMap(Pos, Cell),
    min: Pos,
    max: Pos,
    pour: Pos,
    with_floor: bool,
    floor_fixed: bool,

    pub fn init(allocator: Allocator, with_floor: bool) !Cave {
        var self = Cave{
            .grid = std.AutoHashMap(Pos, Cell).init(allocator),
            .min = Pos.init(std.math.maxInt(isize), std.math.maxInt(isize)),
            .max = Pos.init(std.math.minInt(isize), std.math.minInt(isize)),
            .pour = Pos.init(500, 0),
            .with_floor = with_floor,
            .floor_fixed = false,
        };
        try self.set_pos(self.pour, .Source);
        return self;
    }

    pub fn deinit(self: *Cave) void {
        self.grid.deinit();
    }

    fn set_pos(self: *Cave, pos: Pos, what: Cell) !void {
        try self.grid.put(pos, what);
        if (self.min.x > pos.x) self.min.x = pos.x;
        if (self.max.x < pos.x) self.max.x = pos.x;
        if (self.min.y > pos.y) self.min.y = pos.y;
        if (self.max.y < pos.y) self.max.y = pos.y;
    }

    fn fix_floor(self: *Cave) !void {
        if (self.floor_fixed) return; // only once
        self.floor_fixed = true;

        const delta: isize = 1000; // should be enough?
        const minx = self.min.x - delta;
        const maxx = self.max.x + delta;
        const maxy = self.max.y;
        var x: isize = minx;
        while (x <= maxx) : (x += 1) {
            const pos = Pos.init(x, maxy + 2);
            try self.set_pos(pos, .Rock);
        }
    }

    fn join_line(self: *Cave, pre: Pos, pos: Pos) !void {
        if (pre.x == pos.x) {
            const f: isize = if (pre.y < pos.y) pre.y else pos.y;
            const t: isize = if (pre.y < pos.y) pos.y else pre.y;
            var y = f + 1;
            while (y < t) : (y += 1) {
                try self.grid.put(Pos.init(pos.x, y), .Rock);
            }
            return;
        }
        if (pre.y == pos.y) {
            const f: isize = if (pre.x < pos.x) pre.x else pos.x;
            const t: isize = if (pre.x < pos.x) pos.x else pre.x;
            var x = f + 1;
            while (x < t) : (x += 1) {
                try self.grid.put(Pos.init(x, pos.y), .Rock);
            }
            return;
        }
        unreachable;
    }

    pub fn add_line(self: *Cave, line: []const u8) !void {
        var count: usize = 0;
        var it = std.mem.tokenize(u8, line, " ->");
        var pre: Pos = undefined;
        while (it.next()) |what| : (count += 1) {
            // std.debug.print("WHAT [{s}]\n", .{what});
            var pos: Pos = undefined;
            var c: usize = 0;
            var it_coord = std.mem.tokenize(u8, what, ",");
            while (it_coord.next()) |n| : (c += 1) {
                switch (c) {
                    0 => pos.x = try std.fmt.parseInt(isize, n, 10),
                    1 => pos.y = try std.fmt.parseInt(isize, n, 10),
                    else => unreachable,
                }
            }
            try self.set_pos(pos, .Rock);

            count += 1;
            if (count >= 2) try self.join_line(pre, pos);
            pre = pos;
        }
    }

    pub fn show(self: Cave, count: usize) void {
        std.debug.print("-- {} --------\n", .{count});
        var y: isize = self.min.y;
        while (y <= self.max.y) : (y += 1) {
            var x: isize = self.min.x;
            while (x <= self.max.x) : (x += 1) {
                const pos = Pos.init(x, y);
                var c = self.grid.get(pos) orelse .Empty;
                if (c == .Empty and pos.x == self.pour.x and pos.y == self.pour.y) {
                    c = .Source;
                }
                std.debug.print("{c}", .{@enumToInt(c)});
            }
            std.debug.print("\n", .{});
        }
    }

    fn pos_empty(self: Cave, pos: Pos) bool {
        var c = self.grid.get(pos) orelse .Empty;
        return c == .Empty;
    }

    pub fn drop_sand_unit(self: *Cave) !bool {
        var pos = self.pour;
        var fell_off = false;
        MAIN: while (true) {
            var moves: usize = 0;

            // let it fall down as far as possible
            while (true) {
                const d = Pos.init(pos.x, pos.y + 1);
                if (!self.pos_empty(d)) break;
                if (!self.with_floor and pos.y >= self.max.y) {
                    fell_off = true;
                    break :MAIN;
                }
                pos = d;
                moves += 1;
            }

            // down and to the left -- once
            while (true) {
                const d = Pos.init(pos.x-1, pos.y + 1);
                if (!self.pos_empty(d)) break;
                if (!self.with_floor and pos.y >= self.max.y) {
                    fell_off = true;
                    break :MAIN;
                }
                pos = d;
                moves += 1;
                continue :MAIN;
            }

            // down and to the right -- once
            while (true) {
                const d = Pos.init(pos.x+1, pos.y + 1);
                if (!self.pos_empty(d)) break;
                if (!self.with_floor and pos.y >= self.max.y) {
                    fell_off = true;
                    break :MAIN;
                }
                pos = d;
                moves += 1;
                continue :MAIN;
            }

            if (moves <= 0) break;
        }
        if (!self.with_floor and fell_off) return false;

        try self.set_pos(pos, .Sand);
        if (self.with_floor and pos.y == self.pour.y) return false;

        return true;
    }

    pub fn drop_sand_until_stable(self: *Cave) !usize {
        if (self.with_floor) try self.fix_floor();
        var count: usize = 0;
        while (true) {
            // with a floor, we stop when it is already stable
            if (self.with_floor) count += 1;

            const good = try self.drop_sand_unit();
            // if (!self.with_floor) self.show(count);
            if (!good) break;

            // without a floor, we stop right before it is stable
            if (!self.with_floor) count += 1;
        }
        return count;
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\498,4 -> 498,6 -> 496,6
        \\503,4 -> 502,4 -> 502,9 -> 494,9
    ;

    var cave = try Cave.init(std.testing.allocator, false);
    defer cave.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cave.add_line(line);
    }

    const count = try cave.drop_sand_until_stable();
    try testing.expectEqual(@as(usize, 24), count);
}

test "sample part 2" {
    const data: []const u8 =
        \\498,4 -> 498,6 -> 496,6
        \\503,4 -> 502,4 -> 502,9 -> 494,9
    ;

    var cave = try Cave.init(std.testing.allocator, true);
    defer cave.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cave.add_line(line);
    }

    const count = try cave.drop_sand_until_stable();
    try testing.expectEqual(@as(usize, 93), count);
}
