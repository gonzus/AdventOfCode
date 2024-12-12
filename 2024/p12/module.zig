const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const SIZE = 140;

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            return .{ .x = x, .y = y };
        }
    };

    const Delta = struct {
        x: isize,
        y: isize,

        pub fn init(x: isize, y: isize) Delta {
            return .{ .x = x, .y = y };
        }
    };
    const DeltaNeighbor: [4]Delta = .{
        Delta.init(-1, 0),
        Delta.init(1, 0),
        Delta.init(0, -1),
        Delta.init(0, 1),
    };
    const DeltaCorner: [4]Delta = .{
        Delta.init(-1, -1),
        Delta.init(1, -1),
        Delta.init(-1, 1),
        Delta.init(1, 1),
    };

    sides: bool,
    grid: [SIZE][SIZE]u8,
    rows: usize,
    cols: usize,
    visited: std.AutoHashMap(Pos, void),
    plot: std.AutoHashMap(Pos, void),

    pub fn init(allocator: Allocator, sides: bool) Module {
        return .{
            .sides = sides,
            .grid = undefined,
            .rows = 0,
            .cols = 0,
            .visited = std.AutoHashMap(Pos, void).init(allocator),
            .plot = std.AutoHashMap(Pos, void).init(allocator),
        };
    }

    pub fn deinit(self: *Module) void {
        self.plot.deinit();
        self.visited.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        if (self.cols == 0) {
            self.cols = line.len;
        }
        if (self.cols != line.len) {
            return error.JaggedGrid;
        }

        const y = self.rows;
        self.rows += 1;
        for (line, 0..) |c, x| {
            self.grid[x][y] = c;
        }
    }

    // pub fn show(self: Module) void {
    //     std.debug.print("BOARD {}x{}\n", .{ self.rows, self.cols });
    //     for (0..self.rows) |y| {
    //         for (0..self.cols) |x| {
    //             std.debug.print("{c}", .{self.grid[x][y]});
    //         }
    //         std.debug.print("\n", .{});
    //     }
    // }

    pub fn getTotalPrice(self: *Module) !usize {
        var total: usize = 0;
        self.visited.clearRetainingCapacity();
        for (0..self.rows) |y| {
            for (0..self.cols) |x| {
                const plant = self.grid[x][y];
                const pos = Pos.init(x, y);
                const r = try self.visited.getOrPut(pos);
                if (r.found_existing) continue;

                self.plot.clearRetainingCapacity();
                try self.floodFrom(pos, plant);

                const area = self.plot.count();
                const count = self.countAround(plant);
                total += area * count;
            }
        }
        return total;
    }

    fn floodFrom(self: *Module, pos: Pos, plant: u8) !void {
        if (self.grid[pos.x][pos.y] != plant) return;

        const r = try self.plot.getOrPut(pos);
        if (r.found_existing) return;

        _ = try self.visited.getOrPut(pos);
        for (DeltaNeighbor) |delta| {
            var ix: isize = @intCast(pos.x);
            var iy: isize = @intCast(pos.y);
            ix += delta.x;
            iy += delta.y;
            if (!self.validPos(ix, iy)) continue;
            try self.floodFrom(Pos.init(@intCast(ix), @intCast(iy)), plant);
        }
    }

    fn countAround(self: Module, plant: u8) usize {
        var count: usize = 0;
        var it = self.plot.keyIterator();
        while (it.next()) |p| {
            if (self.sides) {
                count += self.countCorners(p.*, plant);
            } else {
                count += self.countNeighbors(p.*, plant);
            }
        }
        return count;
    }

    fn countNeighbors(self: Module, pos: Pos, plant: u8) usize {
        var count: usize = 0;
        for (DeltaNeighbor) |delta| {
            count += self.checkNeighbor(pos, delta, plant);
        }
        return count;
    }

    fn countCorners(self: Module, pos: Pos, plant: u8) usize {
        var count: usize = 0;
        for (DeltaCorner) |delta| {
            count += self.checkCorner(pos, delta, plant);
        }
        return count;
    }

    fn checkNeighbor(self: Module, pos: Pos, delta: Delta, plant: u8) usize {
        var ix: isize = @intCast(pos.x);
        var iy: isize = @intCast(pos.y);
        ix += delta.x;
        iy += delta.y;
        if (!self.validPos(ix, iy)) return 1;
        if (self.grid[@intCast(ix)][@intCast(iy)] != plant) return 1;
        return 0;
    }

    fn checkCorner(self: Module, pos: Pos, delta: Delta, plant: u8) usize {
        const ix: isize = @intCast(pos.x);
        const iy: isize = @intCast(pos.y);
        const nx = ix + delta.x;
        const ny = iy + delta.y;

        var pc: u8 = 0;
        var px: u8 = 0;
        var py: u8 = 0;
        const vx = nx >= 0 and nx < self.cols;
        const vy = ny >= 0 and ny < self.rows;
        if (vx and vy) {
            pc = self.grid[@intCast(nx)][@intCast(ny)];
        }
        if (vx) {
            px = self.grid[@intCast(nx)][@intCast(iy)];
        }
        if (vy) {
            py = self.grid[@intCast(ix)][@intCast(ny)];
        }
        if (pc != plant and py == plant and px == plant) {
            return 1;
        }
        if (py != plant and px != plant) {
            return 1;
        }
        return 0;
    }

    fn validPos(self: Module, ix: isize, iy: isize) bool {
        if (ix < 0 or ix >= self.cols) return false;
        if (iy < 0 or iy >= self.rows) return false;
        return true;
    }
};

test "sample part 1 example 1" {
    const data =
        \\AAAA
        \\BBCD
        \\BBCC
        \\EEEC
    ;

    var module = Module.init(testing.allocator, false);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalPrice();
    const expected = @as(usize, 140);
    try testing.expectEqual(expected, count);
}

test "sample part 1 example 2" {
    const data =
        \\OOOOO
        \\OXOXO
        \\OOOOO
        \\OXOXO
        \\OOOOO
    ;

    var module = Module.init(testing.allocator, false);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalPrice();
    const expected = @as(usize, 772);
    try testing.expectEqual(expected, count);
}

test "sample part 1 example 3" {
    const data =
        \\RRRRIICCFF
        \\RRRRIICCCF
        \\VVRRRCCFFF
        \\VVRCCCJFFF
        \\VVVVCJJCFE
        \\VVIVCCJJEE
        \\VVIIICJJEE
        \\MIIIIIJJEE
        \\MIIISIJEEE
        \\MMMISSJEEE
    ;

    var module = Module.init(testing.allocator, false);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalPrice();
    const expected = @as(usize, 1930);
    try testing.expectEqual(expected, count);
}

test "sample part 2 example 1" {
    const data =
        \\AAAA
        \\BBCD
        \\BBCC
        \\EEEC
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalPrice();
    const expected = @as(usize, 80);
    try testing.expectEqual(expected, count);
}

test "sample part 2 example 2" {
    const data =
        \\OOOOO
        \\OXOXO
        \\OOOOO
        \\OXOXO
        \\OOOOO
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalPrice();
    const expected = @as(usize, 436);
    try testing.expectEqual(expected, count);
}

test "sample part 2 example 3" {
    const data =
        \\EEEEE
        \\EXXXX
        \\EEEEE
        \\EXXXX
        \\EEEEE
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalPrice();
    const expected = @as(usize, 236);
    try testing.expectEqual(expected, count);
}

test "sample part 2 example 4" {
    const data =
        \\AAAAAA
        \\AAABBA
        \\AAABBA
        \\ABBAAA
        \\ABBAAA
        \\AAAAAA
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalPrice();
    const expected = @as(usize, 368);
    try testing.expectEqual(expected, count);
}

test "sample part 2 example 5" {
    const data =
        \\RRRRIICCFF
        \\RRRRIICCCF
        \\VVRRRCCFFF
        \\VVRCCCJFFF
        \\VVVVCJJCFE
        \\VVIVCCJJEE
        \\VVIIICJJEE
        \\MIIIIIJJEE
        \\MIIISIJEEE
        \\MMMISSJEEE
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getTotalPrice();
    const expected = @as(usize, 1206);
    try testing.expectEqual(expected, count);
}
