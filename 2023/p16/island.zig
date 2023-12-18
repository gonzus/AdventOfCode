const std = @import("std");
const testing = std.testing;
const Grid = @import("./util/grid.zig").Grid;
const Pos = @import("./util/grid.zig").Pos;
const Dir = @import("./util/grid.zig").Direction;

const Allocator = std.mem.Allocator;

pub const Map = struct {
    const Data = Grid(Piece);

    const Piece = enum(u8) {
        Empty = '.',
        MirrorLR = '\\',
        MirrorRL = '/',
        SplitterHor = '-',
        SplitterVer = '|',

        pub fn parse(c: u8) Piece {
            const self: Piece = switch (c) {
                '.' => .Empty,
                '\\' => .MirrorLR,
                '/' => .MirrorRL,
                '-' => .SplitterHor,
                '|' => .SplitterVer,
                else => unreachable,
            };
            return self;
        }
    };

    allocator: Allocator,
    grid: Data,
    energized: std.AutoHashMap(Pos, void),
    best: usize,

    pub fn init(allocator: Allocator) Map {
        var self = Map{
            .allocator = allocator,
            .grid = Data.init(allocator, .Empty),
            .energized = std.AutoHashMap(Pos, void).init(allocator),
            .best = 0,
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.energized.deinit();
        self.grid.deinit();
    }

    pub fn reset(self: *Map) !void {
        self.energized.clearRetainingCapacity();
    }

    pub fn addLine(self: *Map, line: []const u8) !void {
        try self.grid.ensureCols(line.len);
        try self.grid.ensureExtraRow();
        const y = self.grid.rows();
        for (line, 0..) |c, x| {
            const piece = Piece.parse(c);
            try self.grid.set(x, y, piece);
        }
    }

    pub fn show(self: Map) void {
        std.debug.print("Map: {} x {}\n", .{ self.grid.rows(), self.grid.cols() });
        for (0..self.grid.rows()) |y| {
            for (0..self.grid.cols()) |x| {
                const l: u8 = if (self.energized.contains(Pos.init(x, y))) '#' else '.';
                std.debug.print("{c}", .{l});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn getCountEnergizedTiles(self: *Map) !usize {
        const start = PosDir.init(Pos.init(0, 0), .E);
        try self.findEnergizedTiles(start);
        return self.energized.count();
    }

    pub fn getBestConfiguration(self: *Map) !usize {
        self.best = 0;
        for (0..self.grid.rows()) |y| {
            try self.tryConfiguration(0, y, .E);
            try self.tryConfiguration(self.grid.cols() - 1, y, .W);
        }
        for (0..self.grid.cols()) |x| {
            try self.tryConfiguration(x, 0, .S);
            try self.tryConfiguration(x, self.grid.rows() - 1, .N);
        }
        return self.best;
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

    const PosDir = struct {
        pos: Pos,
        dir: Dir,

        pub fn init(pos: Pos, dir: Dir) PosDir {
            return PosDir{ .pos = pos, .dir = dir };
        }
    };

    const Queue = std.ArrayList(PosDir);

    fn addPossibleNeighbor(self: Map, pos: Pos, dir: Dir, queue: *Queue) !void {
        const npos_maybe = self.moveDir(pos, dir);
        if (npos_maybe) |npos| {
            try queue.append(PosDir.init(npos, dir));
        }
    }

    fn findEnergizedTiles(self: *Map, start: PosDir) !void {
        var queue = Queue.init(self.allocator);
        defer queue.deinit();

        var seen = std.AutoHashMap(PosDir, void).init(self.allocator);
        defer seen.deinit();

        _ = try queue.append(start);
        while (queue.items.len > 0) {
            const pd = queue.swapRemove(0);
            const cpos = pd.pos;
            const cdir = pd.dir;

            const entry_seen = try seen.getOrPut(pd);
            if (entry_seen.found_existing) continue;

            _ = try self.energized.getOrPut(cpos);

            // TODO: instead of adding the immediate neighbor in each case,
            // we could quickly find the farthest possible neighbor in each direction,
            // and avoid adding all those intermmediate nodes to the graph
            var piece = self.grid.get(cpos.x, cpos.y);
            switch (piece) {
                .Empty => {
                    try self.addPossibleNeighbor(cpos, cdir, &queue);
                },
                .MirrorLR => {
                    const ndir: Dir = switch (cdir) {
                        .N => .W,
                        .S => .E,
                        .E => .S,
                        .W => .N,
                    };
                    try self.addPossibleNeighbor(cpos, ndir, &queue);
                },
                .MirrorRL => {
                    const ndir: Dir = switch (cdir) {
                        .N => .E,
                        .S => .W,
                        .E => .N,
                        .W => .S,
                    };
                    try self.addPossibleNeighbor(cpos, ndir, &queue);
                },
                .SplitterHor => {
                    switch (cdir) {
                        .N, .S => {
                            try self.addPossibleNeighbor(cpos, .E, &queue);
                            try self.addPossibleNeighbor(cpos, .W, &queue);
                        },
                        .E, .W => {
                            try self.addPossibleNeighbor(cpos, cdir, &queue);
                        },
                    }
                },
                .SplitterVer => {
                    switch (cdir) {
                        .N, .S => {
                            try self.addPossibleNeighbor(cpos, cdir, &queue);
                        },
                        .E, .W => {
                            try self.addPossibleNeighbor(cpos, .N, &queue);
                            try self.addPossibleNeighbor(cpos, .S, &queue);
                        },
                    }
                },
            }
        }
    }

    fn tryConfiguration(self: *Map, x: usize, y: usize, dir: Dir) !void {
        try self.reset();
        const start = PosDir.init(Pos.init(x, y), dir);
        try self.findEnergizedTiles(start);
        const count = self.energized.count();
        if (self.best < count) self.best = count;
    }
};

test "sample part 1" {
    const data =
        \\.|...\....
        \\|.-.\.....
        \\.....|-...
        \\........|.
        \\..........
        \\.........\
        \\..../.\\..
        \\.-.-/..|..
        \\.|....-|.\
        \\..//.|....
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }
    // map.show();

    const count = try map.getCountEnergizedTiles();
    const expected = @as(usize, 46);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\.|...\....
        \\|.-.\.....
        \\.....|-...
        \\........|.
        \\..........
        \\.........\
        \\..../.\\..
        \\.-.-/..|..
        \\.|....-|.\
        \\..//.|....
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }
    // map.show();

    const count = try map.getBestConfiguration();
    const expected = @as(usize, 51);
    try testing.expectEqual(expected, count);
}
