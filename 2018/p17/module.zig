const std = @import("std");
const testing = std.testing;
const grid = @import("./util/grid.zig");

const Allocator = std.mem.Allocator;

pub const Reservoir = struct {
    const Grid = grid.SparseGrid(u8);
    const Pos = grid.Pos;
    const Dir = grid.Direction;

    const Spring = Pos.init(500, 0);

    grid: Grid,
    ymin: isize,
    ymax: isize,
    settled: std.AutoHashMap(Pos, void),
    flowing: std.AutoHashMap(Pos, void),
    seen: std.AutoHashMap(Pos, void),

    pub fn init(allocator: Allocator) Reservoir {
        return .{
            .grid = Grid.init(allocator, '.'),
            .ymin = std.math.maxInt(isize),
            .ymax = std.math.minInt(isize),
            .settled = std.AutoHashMap(Pos, void).init(allocator),
            .flowing = std.AutoHashMap(Pos, void).init(allocator),
            .seen = std.AutoHashMap(Pos, void).init(allocator),
        };
    }

    pub fn deinit(self: *Reservoir) void {
        self.seen.deinit();
        self.flowing.deinit();
        self.settled.deinit();
        self.grid.deinit();
    }

    pub fn addLine(self: *Reservoir, line: []const u8) !void {
        var it = std.mem.tokenizeAny(u8, line, "=, .");
        var x0: isize = 0;
        var x1: isize = 0;
        var y0: isize = 0;
        var y1: isize = 0;
        const d = it.next().?;
        var ok = false;
        if (std.mem.eql(u8, d, "x")) {
            x0 = try std.fmt.parseInt(isize, it.next().?, 10);
            x1 = x0;
            _ = it.next();
            y0 = try std.fmt.parseInt(isize, it.next().?, 10);
            y1 = try std.fmt.parseInt(isize, it.next().?, 10);
            ok = true;
        }
        if (std.mem.eql(u8, d, "y")) {
            y0 = try std.fmt.parseInt(isize, it.next().?, 10);
            y1 = y0;
            _ = it.next();
            x0 = try std.fmt.parseInt(isize, it.next().?, 10);
            x1 = try std.fmt.parseInt(isize, it.next().?, 10);
            ok = true;
        }
        if (!ok) return error.InvalidFormat;

        if (self.ymin > y0) self.ymin = y0;
        if (self.ymax < y1) self.ymax = y1;

        var y: isize = y0;
        while (y <= y1) : (y += 1) {
            var x: isize = x0;
            while (x <= x1) : (x += 1) {
                const pos = Pos.init(x, y);
                try self.grid.set(pos, '#');
            }
        }
    }

    pub fn show(self: Reservoir) void {
        var y: isize = self.grid.min.y;
        while (y <= self.grid.max.y) : (y += 1) {
            var x: isize = self.grid.min.x;
            while (x <= self.grid.max.x) : (x += 1) {
                const pos = Pos.init(x, y);
                const l: u8 = self.grid.get(pos);
                std.debug.print("{c}", .{l});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn getReachableTiles(self: *Reservoir) !usize {
        try self.fillFromSource();
        return self.countTiles(true, true);
    }

    pub fn getRemainingTiles(self: *Reservoir) !usize {
        try self.fillFromSource();
        return self.countTiles(false, true);
    }

    fn fillFromSource(self: *Reservoir) !void {
        self.settled.clearRetainingCapacity();
        self.flowing.clearRetainingCapacity();
        _ = try self.fill(Spring, .S);
    }

    fn isClay(self: Reservoir, pos: Pos) bool {
        return self.grid.get(pos) == '#';
    }

    fn fill(self: *Reservoir, pos: Pos, dir: Dir) !bool {
        _ = try self.flowing.getOrPut(pos);

        const below = Pos.init(pos.x, pos.y + 1);
        if (!self.isClay(below) and !self.flowing.contains(below) and below.y >= 1 and below.y <= self.ymax) {
            _ = try self.fill(below, .S);
        }
        if (!self.isClay(below) and !self.settled.contains(below)) {
            return false;
        }

        var L = Pos.init(pos.x - 1, pos.y);
        const L_filled = self.isClay(L) or !self.flowing.contains(L) and try self.fill(L, .W);

        var R = Pos.init(pos.x + 1, pos.y);
        const R_filled = self.isClay(R) or !self.flowing.contains(R) and try self.fill(R, .E);

        if (dir == .S and L_filled and R_filled) {
            _ = try self.settled.getOrPut(pos);
            while (self.flowing.contains(L)) {
                _ = try self.settled.getOrPut(L);
                L.x -= 1;
            }
            while (self.flowing.contains(R)) {
                _ = try self.settled.getOrPut(R);
                R.x += 1;
            }
        }

        if (dir == .W and (L_filled or self.isClay(L))) return true;
        if (dir == .E and (R_filled or self.isClay(R))) return true;
        return false;
    }

    fn countTiles(self: *Reservoir, flowing: bool, settled: bool) !usize {
        self.seen.clearRetainingCapacity();
        if (flowing) {
            var it = self.flowing.keyIterator();
            while (it.next()) |pos| {
                if (pos.y < self.ymin or pos.y > self.ymax) continue;
                _ = try self.seen.getOrPut(pos.*);
            }
        }
        if (settled) {
            var it = self.settled.keyIterator();
            while (it.next()) |pos| {
                if (pos.y < self.ymin or pos.y > self.ymax) continue;
                _ = try self.seen.getOrPut(pos.*);
            }
        }
        return self.seen.count();
    }
};

test "sample part 1" {
    const data =
        \\x=495, y=2..7
        \\y=7, x=495..501
        \\x=501, y=3..7
        \\x=498, y=2..4
        \\x=506, y=1..2
        \\x=498, y=10..13
        \\x=504, y=10..13
        \\y=13, x=498..504
    ;

    var reservoir = Reservoir.init(testing.allocator);
    defer reservoir.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try reservoir.addLine(line);
    }
    // reservoir.show();

    const count = try reservoir.getReachableTiles();
    const expected = @as(usize, 57);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\x=495, y=2..7
        \\y=7, x=495..501
        \\x=501, y=3..7
        \\x=498, y=2..4
        \\x=506, y=1..2
        \\x=498, y=10..13
        \\x=504, y=10..13
        \\y=13, x=498..504
    ;

    var reservoir = Reservoir.init(testing.allocator);
    defer reservoir.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try reservoir.addLine(line);
    }
    // reservoir.show();

    const count = try reservoir.getRemainingTiles();
    const expected = @as(usize, 29);
    try testing.expectEqual(expected, count);
}
