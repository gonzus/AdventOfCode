const std = @import("std");
const assert = std.debug.assert;

pub const Board = struct {
    const SIZE: usize = 5;

    const Pos = struct {
        l: isize,
        x: usize,
        y: usize,

        pub fn init(l: isize, x: usize, y: usize) Pos {
            var self = Pos{
                .l = l,
                .x = x,
                .y = y,
            };
            return self;
        }
    };

    recursive: bool,
    cells: [2]std.AutoHashMap(Pos, Tile),
    cc: usize,
    cy: usize,
    lmin: isize,
    lmax: isize,

    pub const Tile = enum(u8) {
        Empty = 0,
        Bug = 1,
    };

    pub fn init(recursive: bool) Board {
        var allocator = std.heap.direct_allocator;
        var self = Board{
            .recursive = recursive,
            .cells = undefined,
            .cc = 0,
            .cy = 0,
            .lmin = 0,
            .lmax = 0,
        };
        self.cells[0] = std.AutoHashMap(Pos, Tile).init(allocator);
        self.cells[1] = std.AutoHashMap(Pos, Tile).init(allocator);
        return self;
    }

    pub fn deinit(self: *Board) void {
        self.cells[1].deinit();
        self.cells[0].deinit();
    }

    pub fn put_cell(self: *Board, c: usize, l: isize, x: usize, y: usize, t: Tile) void {
        if (t != Tile.Bug) return;
        const p = Pos.init(l, x, y);
        _ = self.cells[c].put(p, t) catch unreachable;
        if (self.lmin > l) self.lmin = l;
        if (self.lmax < l) self.lmax = l;
    }

    pub fn get_cell(self: Board, c: usize, l: isize, x: usize, y: usize) Tile {
        const p = Pos.init(l, x, y);
        if (!self.cells[c].contains(p)) return Tile.Empty;
        return self.cells[c].get(p).?.value;
    }

    pub fn add_lines(self: *Board, lines: []const u8) void {
        var it = std.mem.separate(lines, "\n");
        while (it.next()) |line| {
            self.add_line(line);
        }
    }

    pub fn add_line(self: *Board, line: []const u8) void {
        var x: usize = 0;
        while (x < line.len) : (x += 1) {
            var t: Tile = Tile.Empty;
            if (line[x] == '#') t = Tile.Bug;
            self.put_cell(0, 0, x, self.cy, t);
        }
        self.cy += 1;
    }

    pub fn check_bug(self: Board, c: usize, l: isize, x: usize, y: usize) usize {
        if (self.get_cell(c, l, x, y) == Tile.Bug) return 1;
        return 0;
    }

    pub fn bugs_in_neighbours(self: *Board, l: isize, x: usize, y: usize) usize {
        const u = l - 1;
        const d = l + 1;
        var bugs: usize = 0;

        // NORTH
        if (y == 0) {
            if (self.recursive) {
                bugs += self.check_bug(self.cc, u, 2, 1);
            }
        } else if (self.recursive and y == 3 and x == 2) {
            var k: usize = 0;
            while (k < SIZE) : (k += 1) {
                bugs += self.check_bug(self.cc, d, k, SIZE - 1);
            }
        } else {
            bugs += self.check_bug(self.cc, l, x, y - 1);
        }

        // SOUTH
        if (y == SIZE - 1) {
            if (self.recursive) {
                bugs += self.check_bug(self.cc, u, 2, 3);
            }
        } else if (self.recursive and y == 1 and x == 2) {
            var k: usize = 0;
            while (k < SIZE) : (k += 1) {
                bugs += self.check_bug(self.cc, d, k, 0);
            }
        } else {
            bugs += self.check_bug(self.cc, l, x, y + 1);
        }

        // WEST
        if (x == 0) {
            if (self.recursive) {
                bugs += self.check_bug(self.cc, u, 1, 2);
            }
        } else if (self.recursive and x == 3 and y == 2) {
            var k: usize = 0;
            while (k < SIZE) : (k += 1) {
                bugs += self.check_bug(self.cc, d, SIZE - 1, k);
            }
        } else {
            bugs += self.check_bug(self.cc, l, x - 1, y);
        }

        // EAST
        if (x == SIZE - 1) {
            if (self.recursive) {
                bugs += self.check_bug(self.cc, u, 3, 2);
            }
        } else if (self.recursive and x == 1 and y == 2) {
            var k: usize = 0;
            while (k < SIZE) : (k += 1) {
                bugs += self.check_bug(self.cc, d, 0, k);
            }
        } else {
            bugs += self.check_bug(self.cc, l, x + 1, y);
        }

        return bugs;
    }

    pub fn step(self: *Board) void {
        const nc = 1 - self.cc;
        self.cells[nc].clear();
        const lmin = self.lmin - 1;
        const lmax = self.lmax + 1;
        var l: isize = lmin;
        while (l <= lmax) : (l += 1) {
            var y: usize = 0;
            while (y < SIZE) : (y += 1) {
                var x: usize = 0;
                while (x < SIZE) : (x += 1) {
                    if (self.recursive and x == 2 and y == 2) continue;
                    const t = self.get_cell(self.cc, l, x, y);
                    var n: Tile = t;
                    const bugs = self.bugs_in_neighbours(l, x, y);
                    // std.debug.warn("Bugs for {} {} {} ({}) = {}\n", l, x, y, t, bugs);
                    switch (t) {
                        .Bug => {
                            if (bugs != 1) n = Tile.Empty;
                        },
                        .Empty => {
                            if (bugs == 1 or bugs == 2) n = Tile.Bug;
                        },
                    }
                    self.put_cell(nc, l, x, y, n);
                }
            }
        }
        self.cc = nc;
    }

    pub fn run_until_repeated(self: *Board) usize {
        const allocator = std.heap.direct_allocator;
        var seen = std.AutoHashMap(usize, void).init(allocator);
        var count: usize = 0;
        while (true) : (count += 1) {
            self.step();
            // self.show();
            const c = self.encode();
            if (seen.contains(c)) break;
            _ = seen.put(c, {}) catch unreachable;
        }
        return count;
    }

    pub fn run_for_N_steps(self: *Board, n: usize) void {
        var count: usize = 0;
        while (count < n) : (count += 1) {
            self.step();
            // self.show();
        }
    }

    pub fn encode(self: Board) usize {
        var code: usize = 0;
        var mask: usize = 1;
        var y: usize = 0;
        while (y < SIZE) : (y += 1) {
            var x: usize = 0;
            while (x < SIZE) : (x += 1) {
                const t = self.get_cell(self.cc, 0, x, y);
                if (t == Tile.Bug) {
                    code |= mask;
                }
                mask <<= 1;
            }
        }
        return code;
    }

    pub fn count_bugs(self: Board) usize {
        var count: usize = 0;
        var l: isize = self.lmin;
        while (l <= self.lmax) : (l += 1) {
            var y: usize = 0;
            while (y < SIZE) : (y += 1) {
                var x: usize = 0;
                while (x < SIZE) : (x += 1) {
                    const t = self.get_cell(self.cc, l, x, y);
                    if (t == Tile.Bug) count += 1;
                }
            }
        }
        return count;
    }

    pub fn show(self: Board) void {
        std.debug.warn("BOARD {} x {}, levels {} - {}\n", SIZE, SIZE, self.lmin, self.lmax);
        var l: isize = self.lmin;
        while (l <= self.lmax) : (l += 1) {
            std.debug.warn("LEVEL {}\n", l);
            var y: usize = 0;
            while (y < SIZE) : (y += 1) {
                var x: usize = 0;
                std.debug.warn("{:4} | ", y);
                while (x < SIZE) : (x += 1) {
                    const t = self.get_cell(self.cc, l, x, y);
                    var c: u8 = ' ';
                    switch (t) {
                        .Empty => c = '.',
                        .Bug => c = '#',
                    }
                    if (x == 2 and y == 2) c = '?';
                    std.debug.warn("{c}", c);
                }
                std.debug.warn("|\n");
            }
        }
    }
};

test "non-recursive simple" {
    const data: []const u8 =
        \\....#
        \\#..#.
        \\#..##
        \\..#..
        \\#....
    ;
    const expected: []const u8 =
        \\####.
        \\....#
        \\##..#
        \\.....
        \\##...
    ;
    var board = Board.init(false);
    defer board.deinit();
    board.add_lines(data);

    const steps: usize = 4;
    board.run_for_N_steps(steps);

    var y: usize = 0;
    var it = std.mem.separate(expected, "\n");
    while (it.next()) |line| : (y += 1) {
        var x: usize = 0;
        while (x < Board.SIZE) : (x += 1) {
            const t = board.get_cell(board.cc, 0, x, y);
            var c: u8 = '.';
            if (t == Board.Tile.Bug) c = '#';
            assert(line[x] == c);
        }
    }
}

test "non-recursive run until repeated" {
    const data: []const u8 =
        \\....#
        \\#..#.
        \\#..##
        \\..#..
        \\#....
    ;
    const expected: []const u8 =
        \\.....
        \\.....
        \\.....
        \\#....
        \\.#...
    ;
    var board = Board.init(false);
    defer board.deinit();
    board.add_lines(data);

    const count = board.run_until_repeated();
    assert(count == 85);

    var y: usize = 0;
    var it = std.mem.separate(expected, "\n");
    while (it.next()) |line| : (y += 1) {
        var x: usize = 0;
        while (x < Board.SIZE) : (x += 1) {
            const t = board.get_cell(board.cc, 0, x, y);
            var c: u8 = '.';
            if (t == Board.Tile.Bug) c = '#';
            assert(line[x] == c);
        }
    }
}

test "recursive run for N steps" {
    const data: []const u8 =
        \\....#
        \\#..#.
        \\#..##
        \\..#..
        \\#....
    ;
    var board = Board.init(true);
    defer board.deinit();
    board.add_lines(data);

    const steps: usize = 10;
    board.run_for_N_steps(steps);
    const count = board.count_bugs();
    assert(count == 99);
}
