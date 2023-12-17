const std = @import("std");
const testing = std.testing;
const Grid = @import("./util/grid.zig").Grid;
const Pos = @import("./util/grid.zig").Pos;
const Dir = @import("./util/grid.zig").Direction;

const Allocator = std.mem.Allocator;

pub const Map = struct {
    const Data = Grid(u8);
    const INFINITY = std.math.maxInt(usize);

    const Turn = enum {
        Left,
        Straight,
        Right,

        pub fn newDir(self: Turn, dir: Dir) Dir {
            return switch (self) {
                .Left => switch (dir) {
                    .N => .W,
                    .S => .E,
                    .E => .N,
                    .W => .S,
                },
                .Straight => switch (dir) {
                    .N => .N,
                    .S => .S,
                    .E => .E,
                    .W => .W,
                },
                .Right => switch (dir) {
                    .N => .E,
                    .S => .W,
                    .E => .S,
                    .W => .N,
                },
            };
        }
    };

    allocator: Allocator,
    grid: Data,

    pub fn init(allocator: Allocator) Map {
        var self = Map{
            .allocator = allocator,
            .grid = Data.init(allocator, 0),
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.grid.deinit();
    }

    pub fn addLine(self: *Map, line: []const u8) !void {
        try self.grid.ensureCols(line.len);
        try self.grid.ensureExtraRow();
        const y = self.grid.rows();
        for (line, 0..) |c, x| {
            try self.grid.set(x, y, c - '0');
        }
    }

    pub fn show(self: Map) void {
        std.debug.print("Map: {} x {}\n", .{ self.grid.rows(), self.grid.cols() });
        for (0..self.grid.rows()) |y| {
            for (0..self.grid.cols()) |x| {
                std.debug.print("{}", .{self.grid.get(x, y)});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn getLeastHeatLoss(self: *Map, min_steps: usize, max_steps: usize) !usize {
        const src = Pos.init(0, 0);
        const tgt = Pos.init(self.grid.cols() - 1, self.grid.rows() - 1);
        const loss = try self.dijkstra(src, tgt, min_steps, max_steps);
        return loss;
    }

    const NodeState = struct {
        pos: Pos,
        dir: Dir,
        steps: u8,

        pub fn init(pos: Pos, dir: Dir, steps: u8) NodeState {
            const state = NodeState{
                .pos = pos,
                .dir = dir,
                .steps = steps,
            };
            return state;
        }
    };

    const NodeStateHeat = struct {
        state: NodeState,
        heat: usize,

        pub fn init(pos: Pos, dir: Dir, steps: u8, heat: usize) NodeStateHeat {
            const state = NodeState.init(pos, dir, steps);
            const nsh = NodeStateHeat{
                .state = state,
                .heat = heat,
            };
            return nsh;
        }

        fn lessThan(_: void, l: NodeStateHeat, r: NodeStateHeat) std.math.Order {
            return std.math.order(l.heat, r.heat);
        }
    };

    fn dijkstra(self: *Map, src: Pos, tgt: Pos, min_steps: usize, max_steps: usize) !usize {
        var visited = std.AutoHashMap(NodeState, void).init(self.allocator);
        defer visited.deinit();

        const PQ = std.PriorityQueue(NodeStateHeat, void, NodeStateHeat.lessThan);
        var pending = PQ.init(self.allocator, {});
        defer pending.deinit();

        try pending.add(NodeStateHeat.init(src, .E, 1, 0));
        try pending.add(NodeStateHeat.init(src, .S, 1, 0));
        while (pending.count() != 0) {
            const cur = pending.remove();
            const cur_visited = try visited.getOrPut(cur.state);
            if (cur_visited.found_existing) continue;

            const pos_maybe = self.moveDir(cur.state.pos, cur.state.dir);
            if (pos_maybe) |pos| {
                const heat = cur.heat + self.grid.get(pos.x, pos.y);
                if (cur.state.steps >= min_steps and cur.state.steps <= max_steps) {
                    if (pos.equal(tgt)) {
                        return heat;
                    }
                }

                for (std.meta.tags(Turn)) |turn| {
                    const dir = turn.newDir(cur.state.dir);
                    var steps: u8 = 1;
                    if (dir == cur.state.dir) {
                        steps = cur.state.steps + 1;
                        if (steps > max_steps) continue;
                    } else {
                        if (cur.state.steps < min_steps) continue;
                    }
                    try pending.add(NodeStateHeat.init(pos, dir, steps, heat));
                }
            }
        }
        return 0;
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
};

test "sample part 1" {
    const data =
        \\2413432311323
        \\3215453535623
        \\3255245654254
        \\3446585845452
        \\4546657867536
        \\1438598798454
        \\4457876987766
        \\3637877979653
        \\4654967986887
        \\4564679986453
        \\1224686865563
        \\2546548887735
        \\4322674655533
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }

    const count = try map.getLeastHeatLoss(1, 3);
    const expected = @as(usize, 102);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\2413432311323
        \\3215453535623
        \\3255245654254
        \\3446585845452
        \\4546657867536
        \\1438598798454
        \\4457876987766
        \\3637877979653
        \\4654967986887
        \\4564679986453
        \\1224686865563
        \\2546548887735
        \\4322674655533
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }

    const count = try map.getLeastHeatLoss(4, 10);
    const expected = @as(usize, 94);
    try testing.expectEqual(expected, count);
}

test "sample part 2 unfortunate" {
    const data =
        \\111111111111
        \\999999999991
        \\999999999991
        \\999999999991
        \\999999999991
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }

    const count = try map.getLeastHeatLoss(4, 10);
    const expected = @as(usize, 71);
    try testing.expectEqual(expected, count);
}
