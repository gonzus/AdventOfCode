const std = @import("std");
const testing = std.testing;
const Grid = @import("./util/grid.zig").Grid;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Maze = struct {
    const Pos = Math.Vector(usize, 2);
    const Data = Grid(u8);

    allocator: Allocator,
    grid: Data,
    start: Pos,
    favorite: usize,

    pub fn init(allocator: Allocator) Maze {
        return .{
            .allocator = allocator,
            .grid = Data.init(allocator, '.'),
            .start = Pos.copy(&[_]usize{ 1, 1 }),
            .favorite = 0,
        };
    }

    pub fn deinit(self: *Maze) void {
        self.grid.deinit();
    }

    pub fn addLine(self: *Maze, line: []const u8) !void {
        self.favorite = try std.fmt.parseUnsigned(usize, line, 10);
    }

    pub fn show(self: *Maze) void {
        std.debug.print("Maze, favorite number is {}\n", .{self.favorite});
        for (0..self.grid.rows()) |y| {
            for (0..self.grid.cols()) |x| {
                std.debug.print("{c}", .{self.grid.get(x, y)});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn countStepsToVisit(self: *Maze, x: usize, y: usize) !usize {
        return try self.exploreTo(x, y, 0);
    }

    pub fn countLocationsForSteps(self: *Maze, steps: usize) !usize {
        return try self.exploreTo(999, 999, steps);
    }

    pub fn exploreTo(self: *Maze, x: usize, y: usize, steps: usize) !usize {
        const src = self.start;
        const tgt = Pos.copy(&[_]usize{ x, y });
        return try self.explore(src, tgt, steps);
    }

    fn isWall(self: Maze, x: usize, y: usize) bool {
        var num: usize = self.favorite;
        num += x * x;
        num += 3 * x;
        num += 2 * x * y;
        num += y;
        num += y * y;
        const bits = @popCount(num);
        return bits % 2 > 0;
    }

    const PosDist = struct {
        pos: Pos,
        dist: usize,

        pub fn init(pos: Pos, dist: usize) PosDist {
            return .{ .pos = pos, .dist = dist };
        }

        fn lessThan(_: void, l: PosDist, r: PosDist) std.math.Order {
            return std.math.order(l.dist, r.dist);
        }
    };

    const PQ = std.PriorityQueue(PosDist, void, PosDist.lessThan);

    fn explore(self: *Maze, src: Pos, tgt: Pos, steps: usize) !usize {
        var queue = PQ.init(self.allocator, {});
        defer queue.deinit();
        var seen = std.AutoHashMap(Pos, void).init(self.allocator);
        defer seen.deinit();
        try queue.add(PosDist.init(src, 0));
        while (queue.count() > 0) {
            const pd = queue.remove();
            if (steps > 0 and pd.dist == steps) return seen.count();
            if (pd.pos.equal(tgt)) return pd.dist;
            try seen.put(pd.pos, {});

            const dxs = [_]isize{ -1, 1, 0, 0 };
            const dys = [_]isize{ 0, 0, -1, 1 };
            for (0..4) |p| {
                var ix: isize = @intCast(pd.pos.v[0]);
                ix += dxs[p];
                if (ix < 0) continue;

                var iy: isize = @intCast(pd.pos.v[1]);
                iy += dys[p];
                if (iy < 0) continue;

                const nx: usize = @intCast(ix);
                const ny: usize = @intCast(iy);
                if (self.isWall(nx, ny)) continue;
                const npos = Pos.copy(&[_]usize{ nx, ny });
                const r = try seen.getOrPut(npos);
                if (r.found_existing) continue;
                try queue.add(PosDist.init(npos, pd.dist + 1));
            }
        }
        return 0;
    }
};

test "sample part 1" {
    const data =
        \\10
    ;

    var maze = Maze.init(std.testing.allocator);
    defer maze.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try maze.addLine(line);
    }
    // maze.show();

    const dist = try maze.countStepsToVisit(7, 4);
    const expected = @as(usize, 11);
    try testing.expectEqual(expected, dist);
}
