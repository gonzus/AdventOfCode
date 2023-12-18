const std = @import("std");
const testing = std.testing;
const Grid = @import("./util/grid.zig").Grid;
const Pos = @import("./util/grid.zig").Pos;

const Allocator = std.mem.Allocator;

pub const Map = struct {
    const Data = Grid(Pipe);

    const Dir = enum(u8) {
        N = 0b0001,
        S = 0b0010,
        E = 0b0100,
        W = 0b1000,

        pub fn opposite(self: Dir) Dir {
            return switch (self) {
                .N => .S,
                .S => .N,
                .E => .W,
                .W => .E,
            };
        }
    };

    const Pipe = enum(u8) {
        EMPTY = '.',
        AA = @intFromEnum(Dir.N) | @intFromEnum(Dir.S) | @intFromEnum(Dir.E) | @intFromEnum(Dir.W),
        NS = @intFromEnum(Dir.N) | @intFromEnum(Dir.S),
        EW = @intFromEnum(Dir.E) | @intFromEnum(Dir.W),
        NE = @intFromEnum(Dir.N) | @intFromEnum(Dir.E),
        NW = @intFromEnum(Dir.N) | @intFromEnum(Dir.W),
        SE = @intFromEnum(Dir.S) | @intFromEnum(Dir.E),
        SW = @intFromEnum(Dir.S) | @intFromEnum(Dir.W),

        pub fn init(c: u8) Pipe {
            const self: Pipe = switch (c) {
                '.' => .EMPTY,
                'S' => .AA,
                '|' => .NS,
                '-' => .EW,
                'L' => .NE,
                'J' => .NW,
                '7' => .SW,
                'F' => .SE,
                else => unreachable,
            };
            return self;
        }

        pub fn labelMap(self: Pipe) []const u8 {
            return switch (self) {
                .EMPTY => ".",
                .AA => "░",
                .NS => "┃",
                .EW => "━",
                .NE => "┗",
                .NW => "┛",
                .SW => "┓",
                .SE => "┏",
            };
        }

        pub fn labelLoop(self: Pipe) []const u8 {
            return switch (self) {
                .EMPTY => ".",
                .AA => "█",
                .NS => "║",
                .EW => "═",
                .NE => "╚",
                .NW => "╝",
                .SW => "╗",
                .SE => "╔",
            };
        }

        pub fn pointsDir(self: Pipe, dir: Dir) bool {
            if (self == .EMPTY) return false;
            return @intFromEnum(self) & @intFromEnum(dir) > 0;
        }

        pub fn isDiagonalBorder(self: Pipe) bool {
            return switch (self) {
                .SW => false,
                .NE => false,
                else => true,
            };
        }
    };

    allocator: Allocator,
    grid: Data,
    loop: std.AutoHashMap(Pos, usize),
    start: Pos,
    equiv: Pipe,

    pub fn init(allocator: Allocator) Map {
        var self = Map{
            .allocator = allocator,
            .grid = Data.init(allocator, .EMPTY),
            .loop = std.AutoHashMap(Pos, usize).init(allocator),
            .start = undefined,
            .equiv = undefined,
        };
        self.equiv = .AA;
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.loop.deinit();
        self.grid.deinit();
    }

    pub fn addLine(self: *Map, line: []const u8) !void {
        try self.grid.ensureCols(line.len);
        try self.grid.ensureExtraRow();
        const rows = self.grid.rows();
        for (line, 0..) |c, x| {
            if (c == '.') continue;

            const pos = Pos.init(x, rows);
            const pipe = Pipe.init(c);
            try self.grid.set(pos.x, pos.y, pipe);
            if (pipe == .AA) {
                self.start = pos;
            }
        }
    }

    pub fn show(self: Map) void {
        std.debug.print("Map: {} x {}\n", .{ self.grid.rows(), self.grid.cols() });
        const solved = self.loop.count() > 0;
        for (0..self.grid.rows()) |y| {
            for (0..self.grid.cols()) |x| {
                var l: []const u8 = ".";
                const pos = Pos.init(x, y);
                const pipe = self.grid.get(pos.x, pos.y);
                l = if (solved and self.loop.contains(pos)) pipe.labelLoop() else pipe.labelMap();
                std.debug.print("{s}", .{l});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn getLongestStepCount(self: *Map) !usize {
        return try self.findLoop();
    }

    pub fn getEnclosedTiles(self: *Map) !usize {
        _ = try self.findLoop();
        var count: usize = 0;
        var delta: usize = 0;
        while (true) : (delta += 1) {
            // move over all diagonals
            var inside = false;
            var x: usize = 0;
            var y: usize = 0;
            if (delta >= self.grid.cols()) {
                y = delta - self.grid.cols();
            } else {
                x = self.grid.cols() - delta;
            }
            if (y > self.grid.rows()) break;
            while (true) {
                // move inside current diagonal
                if (x >= self.grid.cols() or y >= self.grid.rows()) break;
                var empty = true;
                var change = false;
                const pos = Pos.init(x, y);
                if (pos.equal(self.start)) {
                    empty = false;
                    change = self.equiv.isDiagonalBorder();
                } else if (self.loop.contains(pos)) {
                    const pipe = self.grid.get(pos.x, pos.y);
                    empty = false;
                    change = pipe.isDiagonalBorder();
                }
                if (empty and inside) {
                    count += 1;
                }
                if (change) {
                    inside = !inside;
                }
                x += 1;
                y += 1;
            }
        }
        return count;
    }

    fn validMove(self: Map, pos: Pos, dir: Dir) bool {
        return switch (dir) {
            .N => pos.y > 0,
            .S => pos.y < self.grid.rows() - 1,
            .E => pos.x < self.grid.cols() - 1,
            .W => pos.x > 0,
        };
    }

    fn moveDir(self: Map, pos: Pos, dir: Dir) ?Pos {
        if (!self.validMove(pos, dir)) return null;
        switch (dir) {
            .N => return Pos.init(pos.x, pos.y - 1),
            .S => return Pos.init(pos.x, pos.y + 1),
            .E => return Pos.init(pos.x + 1, pos.y),
            .W => return Pos.init(pos.x - 1, pos.y),
        }
    }

    const PosDist = struct {
        pos: Pos,
        dist: usize,

        pub fn init(pos: Pos, dist: usize) PosDist {
            return PosDist{ .pos = pos, .dist = dist };
        }
    };

    fn findLoop(self: *Map) !usize {
        self.loop.clearRetainingCapacity();

        const Queue = std.ArrayList(PosDist);
        var queue = Queue.init(self.allocator);
        defer queue.deinit();

        _ = try queue.append(PosDist.init(self.start, 0));
        var dist_max: usize = 0;
        while (queue.items.len > 0) {
            const pd = queue.swapRemove(0);
            if (dist_max < pd.dist) {
                dist_max = pd.dist;
            }
            const pos = pd.pos;
            const next_dist = pd.dist + 1;
            const pipe = self.grid.get(pos.x, pos.y);

            for (std.meta.tags(Dir)) |dir| {
                if (!pipe.pointsDir(dir)) continue;

                const maybe_next = self.moveDir(pos, dir);
                if (maybe_next) |next| {
                    if (self.loop.contains(next)) continue;

                    const neighbor = self.grid.get(next.x, next.y);
                    if (!neighbor.pointsDir(dir.opposite())) continue;

                    _ = try self.loop.put(next, next_dist);
                    _ = try queue.append(PosDist.init(next, next_dist));
                }
            }
        }
        self.equiv = self.getStartEquiv();
        return dist_max;
    }

    fn getStartEquiv(self: Map) Pipe {
        var mask: u8 = 0;
        for (std.meta.tags(Dir)) |dir| {
            const maybe_next = self.moveDir(self.start, dir);
            if (maybe_next) |next| {
                const maybe_dist = self.loop.get(next);
                if (maybe_dist) |dist| {
                    if (dist != 1) continue;
                    mask |= @intFromEnum(dir);
                }
            }
        }
        // let the chips fall where they may...
        return @enumFromInt(mask);
    }
};

test "sample simple part 1" {
    const data =
        \\.....
        \\.S-7.
        \\.|.|.
        \\.L-J.
        \\.....
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }
    // map.show();

    const count = try map.getLongestStepCount();
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, count);
}

test "sample simple with extra part 1" {
    const data =
        \\-L|F7
        \\7S-7|
        \\L|7||
        \\-L-J|
        \\L|-JF
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }
    // map.show();

    const count = try map.getLongestStepCount();
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, count);
}

test "sample complex part 1" {
    const data =
        \\..F7.
        \\.FJ|.
        \\SJ.L7
        \\|F--J
        \\LJ...
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }
    // map.show();

    const count = try map.getLongestStepCount();
    const expected = @as(usize, 8);
    try testing.expectEqual(expected, count);
}

test "sample complex with extra part 1" {
    const data =
        \\7-F7-
        \\.FJ|7
        \\SJLL7
        \\|F--J
        \\LJ.LJ
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }
    // map.show();

    const count = try map.getLongestStepCount();
    const expected = @as(usize, 8);
    try testing.expectEqual(expected, count);
}

test "sample simple part 2" {
    const data =
        \\...........
        \\.S-------7.
        \\.|F-----7|.
        \\.||.....||.
        \\.||.....||.
        \\.|L-7.F-J|.
        \\.|..|.|..|.
        \\.L--J.L--J.
        \\...........
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }
    // map.show();

    const count = try map.getEnclosedTiles();
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, count);
}

test "sample simple squeezed part 2" {
    const data =
        \\..........
        \\.S------7.
        \\.|F----7|.
        \\.||....||.
        \\.||....||.
        \\.|L-7F-J|.
        \\.|..||..|.
        \\.L--JL--J.
        \\..........
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }
    // map.show();

    const count = try map.getEnclosedTiles();
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, count);
}

test "sample medium part 2" {
    const data =
        \\.F----7F7F7F7F-7....
        \\.|F--7||||||||FJ....
        \\.||.FJ||||||||L7....
        \\FJL7L7LJLJ||LJ.L-7..
        \\L--J.L7...LJS7F-7L7.
        \\....F-J..F7FJ|L7L7L7
        \\....L7.F7||L7|.L7L7|
        \\.....|FJLJ|FJ|F7|.LJ
        \\....FJL-7.||.||||...
        \\....L---J.LJ.LJLJ...
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }
    // map.show();

    const count = try map.getEnclosedTiles();
    const expected = @as(usize, 8);
    try testing.expectEqual(expected, count);
}

test "sample large part 2" {
    const data =
        \\FF7FSF7F7F7F7F7F---7
        \\L|LJ||||||||||||F--J
        \\FL-7LJLJ||||||LJL-77
        \\F--JF--7||LJLJ7F7FJ-
        \\L---JF-JLJ.||-FJLJJ7
        \\|F|F-JF---7F7-L7L|7|
        \\|FFJF7L7F-JF7|JL---7
        \\7-L-JL7||F7|L7F-7F7|
        \\L.L7LFJ|||||FJL7||LJ
        \\L7JLJL-JLJLJL--JLJ.L
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }
    // map.show();

    const count = try map.getEnclosedTiles();
    const expected = @as(usize, 10);
    try testing.expectEqual(expected, count);
}
