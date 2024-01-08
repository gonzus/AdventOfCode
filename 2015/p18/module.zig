const std = @import("std");
const testing = std.testing;
const Grid = @import("./util/grid.zig").Grid;

const Allocator = std.mem.Allocator;

pub const Display = struct {
    const Data = Grid(u8);
    const LIGHT_ON = '#';
    const LIGHT_OFF = '.';

    allocator: Allocator,
    stuck: bool,
    grids: [2]Data,
    current: usize,

    pub fn init(allocator: Allocator, stuck: bool) Display {
        var self = Display{
            .allocator = allocator,
            .stuck = stuck,
            .grids = undefined,
            .current = 0,
        };
        for (self.grids, 0..) |_, pos| {
            self.grids[pos] = Data.init(allocator, LIGHT_OFF);
        }
        return self;
    }

    pub fn deinit(self: *Display) void {
        for (self.grids, 0..) |_, pos| {
            self.grids[pos].deinit();
        }
    }

    pub fn addLine(self: *Display, line: []const u8) !void {
        const curr = &self.grids[self.current];
        const next = &self.grids[1 - self.current];
        try curr.ensureCols(line.len);
        try curr.ensureExtraRow();
        try next.ensureCols(line.len);
        try next.ensureExtraRow();
        const y = curr.rows();
        for (line, 0..) |c, x| {
            try curr.set(x, y, c);
        }
    }

    pub fn show(self: Display) void {
        const curr = &self.grids[self.current];
        std.debug.print("Display: {} x {}\n", .{ curr.rows(), curr.cols() });
        for (0..curr.rows()) |y| {
            for (0..curr.cols()) |x| {
                std.debug.print("{c}", .{curr.get(x, y)});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn getLightsOnAfter(self: *Display, steps: usize) !usize {
        try self.checkStuck();
        for (0..steps) |_| {
            try self.step();
            try self.checkStuck();
        }
        const curr = &self.grids[self.current];
        var count: usize = 0;
        for (0..curr.rows()) |y| {
            for (0..curr.cols()) |x| {
                if (curr.get(x, y) != LIGHT_ON) continue;
                count += 1;
            }
        }
        return count;
    }

    fn step(self: *Display) !void {
        const curr = &self.grids[self.current];
        const next = &self.grids[1 - self.current];
        var y: isize = 0;
        while (y < curr.rows()) : (y += 1) {
            var x: isize = 0;
            while (x < curr.cols()) : (x += 1) {
                var neighbors_on: usize = 0;
                var dx: isize = -1;
                while (dx <= 1) : (dx += 1) {
                    const nx = x + dx;
                    if (nx < 0 or nx >= curr.cols()) continue;
                    var dy: isize = -1;
                    while (dy <= 1) : (dy += 1) {
                        const ny = y + dy;
                        if (ny < 0 or ny >= curr.rows()) continue;
                        if (dx == 0 and dy == 0) continue;
                        if (curr.getSigned(nx, ny) != LIGHT_ON) continue;
                        neighbors_on += 1;
                    }
                }
                const c: u8 = switch (curr.getSigned(x, y)) {
                    LIGHT_ON => if (neighbors_on >= 2 and neighbors_on <= 3) LIGHT_ON else LIGHT_OFF,
                    LIGHT_OFF => if (neighbors_on == 3) LIGHT_ON else LIGHT_OFF,
                    else => return error.InvalidChar,
                };
                try next.setSigned(x, y, c);
            }
        }
        self.current = 1 - self.current;
    }

    fn checkStuck(self: *Display) !void {
        if (!self.stuck) return;

        const curr = &self.grids[self.current];
        try curr.set(0, 0, LIGHT_ON);
        try curr.set(0, curr.rows() - 1, LIGHT_ON);
        try curr.set(curr.cols() - 1, 0, LIGHT_ON);
        try curr.set(curr.cols() - 1, curr.rows() - 1, LIGHT_ON);
    }
};

test "sample part 1" {
    const data =
        \\.#.#.#
        \\...##.
        \\#....#
        \\..#...
        \\#.#..#
        \\####..
    ;

    var display = Display.init(std.testing.allocator, false);
    defer display.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try display.addLine(line);
    }
    // display.show();

    const count = try display.getLightsOnAfter(4);
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\.#.#.#
        \\...##.
        \\#....#
        \\..#...
        \\#.#..#
        \\####..
    ;

    var display = Display.init(std.testing.allocator, true);
    defer display.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try display.addLine(line);
    }
    // display.show();

    const count = try display.getLightsOnAfter(5);
    const expected = @as(usize, 17);
    try testing.expectEqual(expected, count);
}
