const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const SIZE = 50;
    const DOUBLE_SIZE = SIZE * 2;

    const Dir = enum(u8) {
        U = '^',
        R = '>',
        D = 'v',
        L = '<',

        fn movePos(dir: Dir, x: *isize, y: *isize) void {
            switch (dir) {
                .U => y.* -= 1,
                .R => x.* += 1,
                .D => y.* += 1,
                .L => x.* -= 1,
            }
        }

        pub fn parse(c: u8) !Dir {
            for (Dirs) |dir| {
                if (c == @intFromEnum(dir)) return dir;
            }
            return error.InvalidDir;
        }
    };
    const Dirs = std.meta.tags(Dir);

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            return .{ .x = x, .y = y };
        }
    };

    const State = enum { map, moves };

    double: bool,
    grid: [DOUBLE_SIZE][SIZE]u8,
    rows: usize,
    cols: usize,
    state: State,
    pos: Pos,
    moves: std.ArrayList(Dir),

    pub fn init(allocator: Allocator, double: bool) Module {
        return .{
            .double = double,
            .grid = undefined,
            .pos = undefined,
            .rows = 0,
            .cols = 0,
            .state = .map,
            .moves = std.ArrayList(Dir).init(allocator),
        };
    }

    pub fn deinit(self: *Module) void {
        self.moves.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        if (line.len == 0) {
            self.state = .moves;
            return;
        }
        switch (self.state) {
            .map => {
                const mul: usize = if (self.double) 2 else 1;
                const len = line.len * mul;
                if (self.cols == 0) {
                    self.cols = len;
                }
                if (self.cols != len) {
                    return error.JaggedMap;
                }
                const y = self.rows;
                self.rows += 1;
                var x: usize = 0;
                for (line) |c| {
                    switch (c) {
                        '#' => {
                            self.grid[x][y] = '#';
                            x += 1;
                            if (self.double) {
                                self.grid[x][y] = '#';
                                x += 1;
                            }
                        },
                        '.' => {
                            self.grid[x][y] = '.';
                            x += 1;
                            if (self.double) {
                                self.grid[x][y] = '.';
                                x += 1;
                            }
                        },
                        'O' => {
                            if (self.double) {
                                self.grid[x][y] = '[';
                                x += 1;
                                self.grid[x][y] = ']';
                                x += 1;
                            } else {
                                self.grid[x][y] = 'O';
                                x += 1;
                            }
                        },
                        '@' => {
                            self.pos = Pos.init(x, y);
                            if (self.double) {
                                self.grid[x][y] = '.';
                                x += 1;
                                self.grid[x][y] = '.';
                                x += 1;
                            } else {
                                self.grid[x][y] = '.';
                                x += 1;
                            }
                        },
                        else => return error.InvalidChar,
                    }
                }
            },
            .moves => {
                for (line) |c| {
                    try self.moves.append(try Dir.parse(c));
                }
            },
        }
    }

    // pub fn show(self: Module, moves: bool) void {
    //     std.debug.print("Map: {}x{}, pos {} {}\n", .{ self.rows, self.cols, self.pos.x, self.pos.y });
    //     for (0..self.rows) |y| {
    //         for (0..self.cols) |x| {
    //             var l = self.grid[x][y];
    //             if (x == self.pos.x and y == self.pos.y) {
    //                 l = '@';
    //             }
    //             std.debug.print("{c}", .{l});
    //         }
    //         std.debug.print("\n", .{});
    //     }
    //     if (!moves) return;
    //     std.debug.print("Moves: {}\n", .{self.moves.items.len});
    //     for (self.moves.items) |m| {
    //         std.debug.print("{c}", .{@intFromEnum(m)});
    //     }
    //     std.debug.print("\n", .{});
    // }

    pub fn getSumCoordinates(self: *Module) !usize {
        try self.moveAround();
        var sum: usize = 0;
        for (0..self.rows) |y| {
            for (0..self.cols) |x| {
                if (self.grid[x][y] != 'O' and self.grid[x][y] != '[') continue;
                const gps = 100 * y + x;
                sum += gps;
            }
        }
        return sum;
    }

    fn moveAround(self: *Module) !void {
        // self.show(true);
        for (self.moves.items) |move| {
            if (!self.canMoveDir(self.pos, move)) continue;
            self.pos = self.moveDir(self.pos, move);
            // self.show(false);
        }
    }

    fn canMoveDir(self: Module, pos: Pos, dir: Dir) bool {
        var ix: isize = @intCast(pos.x);
        var iy: isize = @intCast(pos.y);
        dir.movePos(&ix, &iy);
        if (!self.validPos(ix, iy)) return false;

        const nx: usize = @intCast(ix);
        const ny: usize = @intCast(iy);
        const npos = Pos.init(nx, ny);

        return switch (self.grid[nx][ny]) {
            '#' => false,
            'O' => self.canMoveDir(npos, dir),
            '[' => self.canMoveDirDouble(npos, dir, nx + 1),
            ']' => self.canMoveDirDouble(npos, dir, nx - 1),
            else => true,
        };
    }

    fn canMoveDirDouble(self: Module, pos: Pos, dir: Dir, ox: usize) bool {
        var ret = self.canMoveDir(pos, dir);
        if (dir == .U or dir == .D) {
            const opos = Pos.init(ox, pos.y);
            ret = ret and self.canMoveDir(opos, dir);
        }
        return ret;
    }

    fn moveDir(self: *Module, pos: Pos, dir: Dir) Pos {
        var ix: isize = @intCast(pos.x);
        var iy: isize = @intCast(pos.y);
        dir.movePos(&ix, &iy);

        const nx: usize = @intCast(ix);
        const ny: usize = @intCast(iy);
        const npos = Pos.init(nx, ny);
        const lpos = Pos.init(nx - 1, ny);
        const rpos = Pos.init(nx + 1, ny);

        switch (self.grid[nx][ny]) {
            'O' => _ = self.moveDir(npos, dir),
            '[' => switch (dir) {
                .U, .D, .L => {
                    _ = self.moveDir(npos, dir);
                    _ = self.moveDir(rpos, dir);
                },
                .R => {
                    _ = self.moveDir(rpos, dir);
                    _ = self.moveDir(npos, dir);
                },
            },
            ']' => switch (dir) {
                .U, .D, .L => {
                    _ = self.moveDir(lpos, dir);
                    _ = self.moveDir(npos, dir);
                },
                .R => {
                    _ = self.moveDir(npos, dir);
                    _ = self.moveDir(lpos, dir);
                },
            },
            else => {},
        }
        self.grid[nx][ny] = self.grid[pos.x][pos.y];
        self.grid[pos.x][pos.y] = '.';
        return npos;
    }

    fn validPos(self: Module, x: isize, y: isize) bool {
        if (x < 0 or x > self.cols - 1) return false;
        if (y < 0 or y > self.rows - 1) return false;
        return true;
    }
};

test "sample part 1" {
    const data =
        \\########
        \\#..O.O.#
        \\##@.O..#
        \\#...O..#
        \\#.#.O..#
        \\#...O..#
        \\#......#
        \\########
        \\
        \\<^^>>>vv<v>>v<<
    ;

    var module = Module.init(testing.allocator, false);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getSumCoordinates();
    const expected = @as(usize, 2028);
    try testing.expectEqual(expected, count);
}

test "sample part 2 small" {
    const data =
        \\#######
        \\#...#.#
        \\#.....#
        \\#..OO@#
        \\#..O..#
        \\#.....#
        \\#######
        \\
        \\<vv<<^^<<^^
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    // expected value was not provided, but it is verified as correct
    const count = try module.getSumCoordinates();
    const expected = @as(usize, 618);
    try testing.expectEqual(expected, count);
}

test "sample part 2 large" {
    const data =
        \\##########
        \\#..O..O.O#
        \\#......O.#
        \\#.OO..O.O#
        \\#..O@..O.#
        \\#O#..O...#
        \\#O..O..O.#
        \\#.OO.O.OO#
        \\#....O...#
        \\##########
        \\
        \\<vv>^<v^>v>^vv^v>v<>v^v<v<^vv<<<^><<><>>v<vvv<>^v^>^<<<><<v<<<v^vv^v>^
        \\vvv<<^>^v^^><<>>><>^<<><^vv^^<>vvv<>><^^v>^>vv<>v<<<<v<^v>^<^^>>>^<v<v
        \\><>vv>v^v^<>><>>>><^^>vv>v<^^^>>v^v^<^^>v^^>v^<^v>v<>>v^v^<v>v^^<^^vv<
        \\<<v<^>>^^^^>>>v^<>vvv^><v<<<>^^^vv^<vvv>^>v<^^^^v<>^>vvvv><>>v^<<^^^^^
        \\^><^><>>><>^^<<^^v>>><^<v>^<vv>>v>>>^v><>^v><<<<v>>v<v<v>vvv>^<><<>^><
        \\^>><>^v<><^vvv<^^<><v<<<<<><^v<<<><<<^^<v<^^^><^>>^<v^><<<^>>^v<v^v<v^
        \\>^>>^v>vv>^<<^v<>><<><<v<<v><>v<^vv<<<>^^v^>^^>>><<^v>>v^v><^^>>^<>vv^
        \\<><^^>^^^<><vvvvv^v<v<<>^v<v>v<<^><<><<><<<^^<<<^<<>><<><^^^>^^<>^>v<>
        \\^^>vv<^v^v<vv>^<><v<^v>^^^>>>^^vvv^>vvv<>>>^<^>>>>>^<<^v>^vvv<>^<><<v>
        \\v^^>>><<^^<>>^v^<v^vv<>v^<<>^<^v^v><^<<<><<^<v><v<>vv>>v><v^<vv<>v^<<^
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getSumCoordinates();
    const expected = @as(usize, 9021);
    try testing.expectEqual(expected, count);
}
