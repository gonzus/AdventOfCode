const std = @import("std");
const testing = std.testing;

pub const Grid = struct {
    const SIZE = 1000;

    const Instruction = enum {
        On,
        Off,
        Toggle,

        pub fn apply(self: Instruction, simple: bool, value: usize) usize {
            const new = if (simple)
                switch (self) {
                    .On => 1,
                    .Off => 0,
                    .Toggle => 1 - value,
                }
            else switch (self) {
                .On => value + 1,
                .Off => if (value > 0) value - 1 else 0,
                .Toggle => value + 2,
            };
            return new;
        }
    };

    simple: bool,
    grid: [SIZE][SIZE]usize,

    pub fn init(simple: bool) Grid {
        const self = Grid{ .simple = simple, .grid = [_][SIZE]usize{[_]usize{0} ** SIZE} ** SIZE };
        return self;
    }

    pub fn addLine(self: *Grid, line: []const u8) !void {
        var count: usize = 0;
        var x0: usize = undefined;
        var x1: usize = undefined;
        var y0: usize = undefined;
        var y1: usize = undefined;
        var instruction: Instruction = undefined;
        var it = std.mem.tokenizeAny(u8, line, " ,");
        while (it.next()) |chunk| : (count += 1) {
            switch (count) {
                0 => {
                    if (std.mem.eql(u8, chunk, "toggle")) {
                        count += 1;
                        instruction = .Toggle;
                        continue;
                    }
                    if (std.mem.eql(u8, chunk, "turn")) {
                        continue;
                    }
                    return error.InvalidData;
                },
                1 => {
                    if (std.mem.eql(u8, chunk, "on")) {
                        instruction = .On;
                        continue;
                    }
                    if (std.mem.eql(u8, chunk, "off")) {
                        instruction = .Off;
                        continue;
                    }
                    return error.InvalidData;
                },
                4 => {
                    if (std.mem.eql(u8, chunk, "through")) {
                        continue;
                    }
                    return error.InvalidData;
                },
                else => {},
            }
            const n = try std.fmt.parseUnsigned(usize, chunk, 10);
            switch (count) {
                2 => y0 = n,
                3 => x0 = n,
                5 => y1 = n,
                6 => x1 = n,
                else => return error.InvalidData,
            }
        }

        for (y0..y1 + 1) |y| {
            for (x0..x1 + 1) |x| {
                self.grid[x][y] = instruction.apply(self.simple, self.grid[x][y]);
            }
        }
    }

    pub fn getTotalBrightness(self: Grid) usize {
        var brightness: usize = 0;
        for (0..SIZE) |y| {
            for (0..SIZE) |x| {
                brightness += self.grid[x][y];
            }
        }
        return brightness;
    }
};

test "sample part 1" {
    var grid = Grid.init(true);
    var expected: usize = 0;
    {
        try grid.addLine("turn on 0,0 through 999,999");
        const brightness = grid.getTotalBrightness();
        expected += Grid.SIZE * Grid.SIZE;
        try testing.expectEqual(expected, brightness);
    }
    {
        try grid.addLine("toggle 0,0 through 999,0");
        const brightness = grid.getTotalBrightness();
        expected -= Grid.SIZE;
        try testing.expectEqual(expected, brightness);
    }
    {
        try grid.addLine("turn off 499,499 through 500,500");
        const brightness = grid.getTotalBrightness();
        expected -= 4;
        try testing.expectEqual(expected, brightness);
    }
}

test "sample part 2" {
    var grid = Grid.init(false);
    var expected: usize = 0;
    {
        try grid.addLine("turn on 0,0 through 0,0");
        const brightness = grid.getTotalBrightness();
        expected += 1;
        try testing.expectEqual(expected, brightness);
    }
    {
        try grid.addLine("toggle 0,0 through 999,999");
        const brightness = grid.getTotalBrightness();
        expected += 2 * Grid.SIZE * Grid.SIZE;
        try testing.expectEqual(expected, brightness);
    }
}
