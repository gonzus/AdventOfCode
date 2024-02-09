const std = @import("std");
const testing = std.testing;
const Grid = @import("./util/grid.zig").Grid;
const Math = @import("./util/math.zig").Math;
const FloodFill = @import("./util/graph.zig").FloodFill;

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
        return try self.exploreSrcTgtSteps(src, tgt, steps);
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

    const FF = FloodFill(Context, Pos);
    const Context = struct {
        maze: *Maze,
        tgt: Pos,
        steps: usize,
        answer: usize,
        nbuf: [10]Pos,
        nlen: usize,

        pub fn init(maze: *Maze, tgt: Pos, steps: usize) Context {
            return .{
                .maze = maze,
                .tgt = tgt,
                .steps = steps,
                .answer = 0,
                .nbuf = undefined,
                .nlen = 0,
            };
        }

        pub fn visit(self: *Context, pos: Pos, dist: usize, seen: usize) !FF.Action {
            if (self.steps > 0 and dist == self.steps) {
                self.answer = seen;
                return .abort;
            }
            if (pos.equal(self.tgt)) {
                self.answer = dist;
                return .abort;
            }
            return .visit;
        }

        pub fn neighbors(self: *Context, pos: Pos) []Pos {
            self.nlen = 0;
            const dxs = [_]isize{ -1, 1, 0, 0 };
            const dys = [_]isize{ 0, 0, -1, 1 };
            for (dxs, dys) |dx, dy| {
                var ix: isize = @intCast(pos.v[0]);
                ix += dx;
                if (ix < 0) continue;

                var iy: isize = @intCast(pos.v[1]);
                iy += dy;
                if (iy < 0) continue;

                const nx: usize = @intCast(ix);
                const ny: usize = @intCast(iy);
                if (self.maze.isWall(nx, ny)) continue;

                self.nbuf[self.nlen] = Pos.copy(&[_]usize{ nx, ny });
                self.nlen += 1;
            }
            return self.nbuf[0..self.nlen];
        }
    };

    fn exploreSrcTgtSteps(self: *Maze, src: Pos, tgt: Pos, steps: usize) !usize {
        var context = Context.init(self, tgt, steps);
        var ff = FF.init(self.allocator, &context);
        defer ff.deinit();
        try ff.run(src);
        return context.answer;
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
