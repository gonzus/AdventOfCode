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

    const Beams = std.AutoHashMap(usize, void);
    const Cache = std.AutoHashMap(V2, usize);

    alloc: std.mem.Allocator,
    size: V2,
    start: V2,
    manifold: [SIZE][SIZE]u8,

    pub fn init(alloc: std.mem.Allocator) Module {
        return .{
            .alloc = alloc,
            .size = V2.init(0, 0),
            .start = undefined,
            .manifold = undefined,
        };
    }

    pub fn deinit(self: *Module) void {
        _ = self;
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
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

    pub fn countBeamSplits(self: *Module) !usize {
        var beams = Beams.init(self.alloc);
        defer beams.deinit();
        try beams.put(self.start.x, {});
        return try self.exploreSplits(&beams);
    }

    pub fn countQuantumTimelines(self: *Module) !usize {
        var cache = Cache.init(self.alloc);
        defer cache.deinit();
        var beams = Beams.init(self.alloc);
        defer beams.deinit();
        try beams.put(self.start.x, {});
        const count = try self.exploreTimelines(self.start.y + 1, &beams, &cache);
        return count;
    }

    fn exploreSplits(self: *Module, beams: *Beams) !usize {
        var count: usize = 0;
        var add = Beams.init(self.alloc);
        defer add.deinit();
        var del = Beams.init(self.alloc);
        defer del.deinit();
        for (self.start.y + 1..self.size.y) |y| {
            add.clearRetainingCapacity();
            del.clearRetainingCapacity();
            var it = beams.keyIterator();
            while (it.next()) |xp| {
                const x = xp.*;
                switch (self.manifold[x][y]) {
                    '.' => continue,
                    '^' => {
                        count += 1;
                        try del.put(x, {});
                        if (x > 0) _ = try add.getOrPut(x - 1);
                        if (x < self.size.x - 1) _ = try add.getOrPut(x + 1);
                    },
                    else => return error.InvalidData,
                }
            }
            var itd = del.keyIterator();
            while (itd.next()) |xp| {
                const x = xp.*;
                _ = beams.remove(x);
            }
            var ita = add.keyIterator();
            while (ita.next()) |xp| {
                const x = xp.*;
                _ = try beams.put(x, {});
            }
        }
        return count;
    }

    fn exploreTimelines(self: *Module, y: usize, beams: *Beams, cache: *Cache) !usize {
        if (y >= self.size.y - 1) return 1;

        var count: usize = 0;
        var next = try beams.clone();
        defer next.deinit();
        var it = beams.keyIterator();
        while (it.next()) |xp| {
            const x = xp.*;
            const pos = V2.init(x, y);
            if (cache.get(pos)) |val| {
                count += val;
                continue;
            }
            var val: usize = 0;
            switch (self.manifold[x][y]) {
                '.' => {
                    val += try self.exploreTimelines(y + 1, &next, cache);
                },
                '^' => {
                    _ = next.remove(x);
                    if (x > 0) {
                        if (next.get(x - 1)) |_| {} else {
                            _ = try next.put(x - 1, {});
                            val += try self.exploreTimelines(y + 1, &next, cache);
                            _ = next.remove(x - 1);
                        }
                    }
                    if (x < self.size.x - 1) {
                        if (next.get(x + 1)) |_| {} else {
                            _ = try next.put(x + 1, {});
                            val += try self.exploreTimelines(y + 1, &next, cache);
                            _ = next.remove(x + 1);
                        }
                    }
                    _ = try next.put(x, {});
                },
                else => return error.InvalidData,
            }
            try cache.put(pos, val);
            count += val;
        }
        return count;
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

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |line| {
        try module.addLine(line);
    }

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

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const fresh = try module.countQuantumTimelines();
    const expected = @as(usize, 40);
    try testing.expectEqual(expected, fresh);
}
