const std = @import("std");
const testing = std.testing;

pub const Game = struct {
    const SIZE = 150;
    const XMAS = "XMAS";
    const MAS = "MAS";

    grid: [SIZE][SIZE]u8,
    rows: usize,
    cols: usize,

    pub fn init() Game {
        const self = Game{
            .grid = undefined,
            .rows = 0,
            .cols = 0,
        };
        return self;
    }

    pub fn deinit(_: *Game) void {}

    pub fn addLine(self: *Game, line: []const u8) !void {
        if (self.cols == 0) {
            self.cols = line.len;
        }
        if (self.cols != line.len) {
            return error.JaggedGrid;
        }
        for (line, 0..) |c, x| {
            self.grid[x][self.rows] = c;
        }
        self.rows += 1;
    }

    const Delta = struct {
        x: isize,
        y: isize,

        pub fn init(x: isize, y: isize) Delta {
            return .{ .x = x, .y = y };
        }
    };

    const Dir = enum {
        N,
        NE,
        E,
        SE,
        S,
        SW,
        W,
        NW,

        pub fn delta(dir: Dir) Delta {
            return switch (dir) {
                .N => Delta.init(0, -1),
                .NE => Delta.init(1, -1),
                .E => Delta.init(1, 0),
                .SE => Delta.init(1, 1),
                .S => Delta.init(0, 1),
                .SW => Delta.init(-1, 1),
                .W => Delta.init(-1, 0),
                .NW => Delta.init(-1, -1),
            };
        }
    };

    pub fn countXMAS(self: Game) !usize {
        var count: usize = 0;
        for (0..self.cols) |y| {
            for (0..self.rows) |x| {
                for (std.enums.values(Dir)) |dir| {
                    if (!self.checkXMAS(x, y, dir)) continue;
                    count += 1;
                }
            }
        }
        return count;
    }

    pub fn countMAS(self: Game) !usize {
        var count: usize = 0;
        for (0..self.cols) |y| {
            for (0..self.rows) |x| {
                if (!self.checkMAS(x, y)) continue;
                count += 1;
            }
        }
        return count;
    }

    fn checkXMAS(self: Game, x: usize, y: usize, dir: Dir) bool {
        var ix: isize = @intCast(x);
        var iy: isize = @intCast(y);
        const delta = dir.delta();
        for (XMAS) |c| {
            if (ix < 0 or ix >= self.cols) return false;
            if (iy < 0 or iy >= self.rows) return false;
            const nx: usize = @intCast(ix);
            const ny: usize = @intCast(iy);
            if (self.grid[nx][ny] != c) return false;
            ix += delta.x;
            iy += delta.y;
        }
        return true;
    }

    fn checkMAS(self: Game, x: usize, y: usize) bool {
        // This could be made generic, based on constant MAS.
        // But I cannot be arsed.
        if (x < 1 or y < 1) return false;
        if (x + 1 >= self.cols or y + 1 >= self.rows) return false;
        if (self.grid[x][y] != 'A') return false;
        var found: usize = 0;
        if (self.grid[x - 1][y - 1] == 'M' and self.grid[x + 1][y + 1] == 'S') found += 1;
        if (self.grid[x - 1][y - 1] == 'S' and self.grid[x + 1][y + 1] == 'M') found += 1;
        if (self.grid[x - 1][y + 1] == 'M' and self.grid[x + 1][y - 1] == 'S') found += 1;
        if (self.grid[x - 1][y + 1] == 'S' and self.grid[x + 1][y - 1] == 'M') found += 1;
        return found == 2;
    }
};

test "sample part 1" {
    const data =
        \\MMMSXXMASM
        \\MSAMXMSMSA
        \\AMXSXMAAMM
        \\MSAMASMSMX
        \\XMASAMXAMM
        \\XXAMMXXAMA
        \\SMSMSASXSS
        \\SAXAMASAAA
        \\MAMMMXMMMM
        \\MXMXAXMASX
    ;

    var game = Game.init();
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }

    const count = try game.countXMAS();
    const expected = @as(usize, 18);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\MMMSXXMASM
        \\MSAMXMSMSA
        \\AMXSXMAAMM
        \\MSAMASMSMX
        \\XMASAMXAMM
        \\XXAMMXXAMA
        \\SMSMSASXSS
        \\SAXAMASAAA
        \\MAMMMXMMMM
        \\MXMXAXMASX
    ;

    var game = Game.init();
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }

    const count = try game.countMAS();
    const expected = @as(usize, 9);
    try testing.expectEqual(expected, count);
}
