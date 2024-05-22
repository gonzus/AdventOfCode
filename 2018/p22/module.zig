const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Cave = struct {
    const Pos = Math.Vector(usize, 2);
    const Score = std.AutoHashMap(State, usize);
    const PQ = std.PriorityQueue(State, *Score, State.cmp);

    const Dx = [_]isize{ -1, 1, 0, 0 };
    const Dy = [_]isize{ 0, 0, -1, 1 };

    const Kind = enum(usize) {
        rocky,
        wet,
        narrow,

        pub fn decode(num: usize) !Kind {
            for (Kinds) |k| {
                if (@intFromEnum(k) == num) return k;
            }
            return error.InvalidKind;
        }

        pub fn riskLevel(self: Kind) usize {
            return @intFromEnum(self);
        }
    };
    const Kinds = std.meta.tags(Kind);

    const Tool = enum(usize) {
        none,
        torch,
        gear,

        pub fn canBeUsed(self: Tool, kind: Kind) bool {
            return switch (self) {
                .none => kind != .rocky,
                .torch => kind != .wet,
                .gear => kind != .narrow,
            };
        }
    };
    const Tools = std.meta.tags(Tool);

    allocator: Allocator,
    depth: usize,
    mouth: Pos,
    target: Pos,
    cache: std.AutoHashMap(Pos, usize),
    fScore: Score,
    gScore: Score,

    pub fn init(allocator: Allocator) Cave {
        return .{
            .allocator = allocator,
            .depth = undefined,
            .mouth = Pos.init(),
            .target = undefined,
            .cache = std.AutoHashMap(Pos, usize).init(allocator),
            .fScore = Score.init(allocator),
            .gScore = Score.init(allocator),
        };
    }

    pub fn deinit(self: *Cave) void {
        self.gScore.deinit();
        self.fScore.deinit();
        self.cache.deinit();
    }

    pub fn addLine(self: *Cave, line: []const u8) !void {
        var it = std.mem.tokenizeAny(u8, line, " :,");
        const field = it.next().?;
        if (std.mem.eql(u8, field, "depth")) {
            self.depth = try std.fmt.parseUnsigned(usize, it.next().?, 10);
            return;
        }
        if (std.mem.eql(u8, field, "target")) {
            const x = try std.fmt.parseUnsigned(usize, it.next().?, 10);
            const y = try std.fmt.parseUnsigned(usize, it.next().?, 10);
            self.target = Pos.copy(&[_]usize{ x, y });
            return;
        }
        return error.InvalidInput;
    }

    pub fn show(self: Cave) void {
        std.debug.print("Cave with depth={}, target={}\n", .{ self.depth, self.target });
    }

    pub fn getRiskLevel(self: *Cave) !usize {
        var level: usize = 0;
        for (self.mouth.v[0]..self.target.v[0] + 1) |x| {
            for (self.mouth.v[1]..self.target.v[1] + 1) |y| {
                const pos = Pos.copy(&[_]usize{ x, y });
                const kind = try self.regionKind(pos);
                level += kind.riskLevel();
            }
        }
        return level;
    }

    pub fn findBestRoute(self: *Cave) !usize {
        return try self.findRoute();
    }

    const Error = error{OutOfMemory};

    fn regionGeologicIndex(self: *Cave, pos: Pos) !usize {
        if (self.cache.get(pos)) |v| {
            return v;
        }

        const v: usize = blk: {
            if (pos.equal(self.mouth)) break :blk 0;
            if (pos.equal(self.target)) break :blk 0;
            if (pos.v[1] == 0) break :blk pos.v[0] * 16807;
            if (pos.v[0] == 0) break :blk pos.v[1] * 48271;
            const x1 = Pos.copy(&[_]usize{ pos.v[0] - 1, pos.v[1] });
            const y1 = Pos.copy(&[_]usize{ pos.v[0], pos.v[1] - 1 });
            break :blk try self.regionErosionLevel(x1) * try self.regionErosionLevel(y1);
        };
        try self.cache.put(pos, v);
        return v;
    }

    fn regionErosionLevel(self: *Cave, pos: Pos) Error!usize {
        return (try self.regionGeologicIndex(pos) + self.depth) % 20183;
    }

    fn regionKind(self: *Cave, pos: Pos) !Kind {
        return try Kind.decode(try self.regionErosionLevel(pos) % 3);
    }

    const State = struct {
        pos: Pos,
        tool: Tool,

        pub fn init(pos: Pos, tool: Tool) State {
            return .{ .pos = pos, .tool = tool };
        }

        fn cmp(fScore: *Score, l: State, r: State) std.math.Order {
            const le = fScore.*.get(l) orelse Math.INFINITY;
            const re = fScore.*.get(r) orelse Math.INFINITY;
            const oe = std.math.order(le, re);
            if (oe != .eq) return oe;
            const ot = std.math.order(@intFromEnum(l.tool), @intFromEnum(r.tool));
            return ot;
        }
    };

    fn findRoute(self: *Cave) !usize {
        std.debug.assert((try self.regionKind(self.target)) == .rocky);

        self.fScore.clearRetainingCapacity();
        self.gScore.clearRetainingCapacity();

        var openSet = PQ.init(self.allocator, &self.fScore);
        defer openSet.deinit();

        const start = State.init(self.mouth, .torch);
        try self.recordState(&openSet, start, 0);

        var best: usize = Math.INFINITY;
        while (openSet.count() != 0) {
            const current = openSet.remove();
            const gCurrent = self.gScore.get(current) orelse return error.InconsistentScore;
            if (current.pos.equal(self.target)) {
                var elapsed: usize = gCurrent;
                if (current.tool != .torch) {
                    elapsed += 7;
                }
                if (best != Math.INFINITY) return @min(best, elapsed);
                best = elapsed;
            }
            for (Dx, Dy) |dx, dy| {
                var ix: isize = @intCast(current.pos.v[0]);
                ix += dx;
                if (ix < 0) continue;
                var iy: isize = @intCast(current.pos.v[1]);
                iy += dy;
                if (iy < 0) continue;
                const nx: usize = @intCast(ix);
                const ny: usize = @intCast(iy);
                const npos = Pos.copy(&[_]usize{ nx, ny });
                const ckind = try self.regionKind(current.pos);
                const nkind = try self.regionKind(npos);
                var neighbor = State.init(npos, .none);
                for (Tools) |ntool| {
                    if (!ntool.canBeUsed(nkind)) continue;
                    if (!ntool.canBeUsed(ckind)) continue;

                    var elapsed: usize = 1; // to move there
                    if (ntool != current.tool) {
                        elapsed += 7; // to switch tools
                    }
                    neighbor.tool = ntool;
                    var gNeighbor: usize = Math.INFINITY;
                    if (self.gScore.get(neighbor)) |v| gNeighbor = v;
                    const tentative = gCurrent + elapsed;
                    if (tentative >= gNeighbor) continue;

                    try self.recordState(&openSet, neighbor, tentative);
                }
            }
        }
        return 0;
    }

    fn recordState(self: *Cave, openSet: *PQ, state: State, gValue: usize) !void {
        const hValue = state.pos.manhattanDist(self.target);
        try self.gScore.put(state, gValue);
        try self.fScore.put(state, gValue + hValue);
        _ = try openSet.*.add(state);
    }
};

test "sample part 1" {
    const data =
        \\depth: 510
        \\target: 10,10
    ;

    var cave = Cave.init(std.testing.allocator);
    defer cave.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cave.addLine(line);
    }
    // cave.show();

    {
        const pos = Cave.Pos.copy(&[_]usize{ 0, 0 });
        try testing.expectEqual(0, cave.regionGeologicIndex(pos));
        try testing.expectEqual(510, cave.regionErosionLevel(pos));
        try testing.expectEqual(Cave.Kind.rocky, cave.regionKind(pos));
    }
    {
        const pos = Cave.Pos.copy(&[_]usize{ 1, 0 });
        try testing.expectEqual(16807, cave.regionGeologicIndex(pos));
        try testing.expectEqual(17317, cave.regionErosionLevel(pos));
        try testing.expectEqual(Cave.Kind.wet, cave.regionKind(pos));
    }
    {
        const pos = Cave.Pos.copy(&[_]usize{ 0, 1 });
        try testing.expectEqual(48271, cave.regionGeologicIndex(pos));
        try testing.expectEqual(8415, cave.regionErosionLevel(pos));
        try testing.expectEqual(Cave.Kind.rocky, cave.regionKind(pos));
    }
    {
        const pos = Cave.Pos.copy(&[_]usize{ 1, 1 });
        try testing.expectEqual(145722555, cave.regionGeologicIndex(pos));
        try testing.expectEqual(1805, cave.regionErosionLevel(pos));
        try testing.expectEqual(Cave.Kind.narrow, cave.regionKind(pos));
    }
    {
        const pos = Cave.Pos.copy(&[_]usize{ 10, 10 });
        try testing.expectEqual(0, cave.regionGeologicIndex(pos));
        try testing.expectEqual(510, cave.regionErosionLevel(pos));
        try testing.expectEqual(Cave.Kind.rocky, cave.regionKind(pos));
    }

    const level = try cave.getRiskLevel();
    const expected = @as(usize, 114);
    try testing.expectEqual(expected, level);
}

test "sample part 2" {
    const data =
        \\depth: 510
        \\target: 10,10
    ;

    var cave = Cave.init(std.testing.allocator);
    defer cave.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cave.addLine(line);
    }
    // cave.show();

    const elapsed = try cave.findBestRoute();
    const expected = @as(usize, 45);
    try testing.expectEqual(expected, elapsed);
}
