const std = @import("std");
const testing = std.testing;

pub const Map = struct {
    const SIZE = 150;

    const Dir = enum(u8) {
        U = 0b00010,
        R = 0b00100,
        D = 0b01000,
        L = 0b10000,

        fn turnRight(dir: *Dir) void {
            dir.* = switch (dir.*) {
                .U => .R,
                .R => .D,
                .D => .L,
                .L => .U,
            };
        }

        fn takeStep(dir: Dir, x: *isize, y: *isize) void {
            switch (dir) {
                .U => y.* -= 1,
                .R => x.* += 1,
                .D => y.* += 1,
                .L => x.* -= 1,
            }
        }
    };

    const Mark = struct {
        const MASK_OCCUPIED: u8 = 0b00001;

        // 0bxxxxxxxx
        //         |+- occupied?
        //         +-- visited moving U
        //        +--- visited moving R
        //       +---- visited moving D
        //      +----- visited moving L
        mask: u8,

        pub fn init() Mark {
            return .{ .mask = 0 };
        }

        pub fn isOccupied(self: Mark) bool {
            return self.mask & MASK_OCCUPIED > 0;
        }

        pub fn markOccupied(self: *Mark) void {
            self.mask |= MASK_OCCUPIED;
        }

        pub fn markUnoccupied(self: *Mark) void {
            self.mask &= ~MASK_OCCUPIED;
        }

        pub fn visitedGoing(self: Mark, dir: Dir) bool {
            return self.mask & @intFromEnum(dir) > 0;
        }

        pub fn visitedEver(self: Mark) bool {
            const MASK_ALL: u8 = @intFromEnum(Dir.U) | @intFromEnum(Dir.R) | @intFromEnum(Dir.D) | @intFromEnum(Dir.L);
            return self.mask & MASK_ALL > 0;
        }

        pub fn markVisitedGoing(self: *Mark, dir: Dir) void {
            self.mask |= @intFromEnum(dir);
        }

        pub fn forgetVisits(self: *Mark) void {
            self.mask &= MASK_OCCUPIED;
        }
    };

    board: [SIZE][SIZE]Mark,
    rows: usize,
    cols: usize,
    gx: usize,
    gy: usize,
    gd: Dir,

    pub fn init() Map {
        const self = Map{
            .board = undefined,
            .rows = 0,
            .cols = 0,
            .gx = 0,
            .gy = 0,
            .gd = .U,
        };
        return self;
    }

    pub fn deinit(_: *Map) void {}

    pub fn addLine(self: *Map, line: []const u8) !void {
        if (self.cols == 0) {
            self.cols = line.len;
        }
        if (self.cols != line.len) {
            return error.JaggedBoard;
        }
        const y = self.rows;
        for (line, 0..) |c, x| {
            self.board[x][y] = Mark.init();
            switch (c) {
                '#' => self.board[x][y].markOccupied(),
                '^' => {
                    self.gx = x;
                    self.gy = y;
                    self.gd = .U;
                    self.board[self.gx][self.gy].markVisitedGoing(self.gd);
                },
                else => {},
            }
        }
        self.rows += 1;
    }

    pub fn countVisited(self: *Map) !usize {
        if (!try self.walkAround()) {
            // was in a loop, return 0 in this case
            return 0;
        }
        var count: usize = 0;
        for (0..self.rows) |y| {
            for (0..self.cols) |x| {
                if (self.board[x][y].visitedEver()) {
                    count += 1;
                }
            }
        }
        return count;
    }

    pub fn countPossibleObstructions(self: *Map) !usize {
        // we could (probably) only attempt to place obstructions around the original path
        // but I cannot be arsed, so I will just brute-force it.
        var count: usize = 0;
        const gx = self.gx;
        const gy = self.gy;
        const gd = self.gd;
        for (0..self.rows) |ny| {
            for (0..self.cols) |nx| {
                if (nx == gx and ny == gy) {
                    continue; // skip guard
                }
                if (self.board[nx][ny].isOccupied()) {
                    continue; // skip occupied
                }
                self.reset(gx, gy, gd);
                self.board[nx][ny].markOccupied();
                if (!try self.walkAround()) {
                    // we managed to put guard in a loop
                    count += 1;
                }
                self.board[nx][ny].markUnoccupied();
            }
        }
        return count;
    }

    fn walkAround(self: *Map) !bool {
        while (true) {
            var ix: isize = @intCast(self.gx);
            var iy: isize = @intCast(self.gy);
            self.gd.takeStep(&ix, &iy);
            if (ix < 0 or ix >= self.cols or iy < 0 or iy >= self.rows) {
                return true;
            }
            const nx: u8 = @intCast(ix);
            const ny: u8 = @intCast(iy);
            if (self.board[nx][ny].isOccupied()) {
                // change direction
                self.gd.turnRight();
            } else {
                // move there
                self.gx = nx;
                self.gy = ny;
            }
            if (self.board[self.gx][self.gy].visitedGoing(self.gd)) {
                // we are in a loop
                return false;
            }
            self.board[self.gx][self.gy].markVisitedGoing(self.gd);
            continue;
        }
        return false;
    }

    fn reset(self: *Map, gx: usize, gy: usize, gd: Dir) void {
        for (0..self.rows) |y| {
            for (0..self.cols) |x| {
                self.board[x][y].forgetVisits();
            }
        }
        self.gx = gx;
        self.gy = gy;
        self.gd = gd;
        self.board[self.gx][self.gy].markVisitedGoing(self.gd);
    }
};

test "sample part 1" {
    const data =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#..^.....
        \\........#.
        \\#.........
        \\......#...
    ;

    var map = Map.init();
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }

    const count = try map.countVisited();
    const expected = @as(usize, 41);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#..^.....
        \\........#.
        \\#.........
        \\......#...
    ;

    var map = Map.init();
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }

    const count = try map.countPossibleObstructions();
    const expected = @as(usize, 6);
    try testing.expectEqual(expected, count);
}
