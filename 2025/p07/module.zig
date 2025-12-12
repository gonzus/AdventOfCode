const std = @import("std");
const testing = std.testing;

pub const Module = struct {
    const SIZE = 150;

    const V2 = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) V2 {
            return .{ .x = x, .y = y };
        }
    };

    size: V2,
    start: V2,
    manifold: [SIZE][SIZE]u8,
    beams: [SIZE]usize,
    splits: usize,
    timelines: usize,

    pub fn init() Module {
        return .{
            .size = V2.init(0, 0),
            .start = undefined,
            .manifold = undefined,
            .beams = undefined,
            .splits = 0,
            .timelines = 0,
        };
    }

    pub fn deinit(_: *Module) void {}

    pub fn parseInput(self: *Module, data: []const u8) !void {
        var it_lines = std.mem.splitScalar(u8, data, '\n');
        while (it_lines.next()) |line| {
            if (self.size.x == 0) self.size.x = line.len;
            if (self.size.x != line.len) return error.InvalidData;
            const y = self.size.y;
            for (0..line.len) |x| {
                self.manifold[x][y] = line[x];
                if (line[x] == 'S') {
                    self.start = V2.init(x, y);
                }
            }
            self.size.y += 1;
        }
    }

    pub fn countBeamSplits(self: *Module) !usize {
        try self.exploreSplits();
        return self.splits;
    }

    pub fn countQuantumTimelines(self: *Module) !usize {
        try self.exploreSplits();
        return self.timelines;
    }

    fn exploreSplits(self: *Module) !void {
        self.splits = 0;
        self.timelines = 0;
        self.beams = @splat(0);
        self.beams[self.start.x] += 1;
        for (self.start.y + 1..self.size.y) |y| {
            for (0..self.size.x) |x| {
                switch (self.manifold[x][y]) {
                    '.' => continue,
                    '^' => {
                        if (self.beams[x] > 0) {
                            self.splits += 1;
                            if (x > 0) self.beams[x - 1] += self.beams[x];
                            if (x < self.size.x - 1) self.beams[x + 1] += self.beams[x];
                            self.beams[x] = 0;
                        }
                    },
                    else => return error.InvalidData,
                }
            }
        }
        for (self.beams) |b| {
            self.timelines += b;
        }
    }
};

test "sample part 1" {
    const data =
        \\.......S.......
        \\...............
        \\.......^.......
        \\...............
        \\......^.^......
        \\...............
        \\.....^.^.^.....
        \\...............
        \\....^.^...^....
        \\...............
        \\...^.^...^.^...
        \\...............
        \\..^...^.....^..
        \\...............
        \\.^.^.^.^.^...^.
        \\...............
    ;

    var module = Module.init();
    defer module.deinit();
    try module.parseInput(data);

    const fresh = try module.countBeamSplits();
    const expected = @as(usize, 21);
    try testing.expectEqual(expected, fresh);
}

test "sample part 2" {
    const data =
        \\.......S.......
        \\...............
        \\.......^.......
        \\...............
        \\......^.^......
        \\...............
        \\.....^.^.^.....
        \\...............
        \\....^.^...^....
        \\...............
        \\...^.^...^.^...
        \\...............
        \\..^...^.....^..
        \\...............
        \\.^.^.^.^.^...^.
        \\...............
    ;

    var module = Module.init();
    defer module.deinit();
    try module.parseInput(data);

    const fresh = try module.countQuantumTimelines();
    const expected = @as(usize, 40);
    try testing.expectEqual(expected, fresh);
}
