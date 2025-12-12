const std = @import("std");
const testing = std.testing;

pub const Module = struct {
    const SHAPE_SIZE = 3;
    const HEURISTIC_FACTOR = 1.1; // assume we will need 10% extra room

    const Shape = struct {
        id: usize,
        grid: [SHAPE_SIZE][SHAPE_SIZE]u8,
        size: usize,
        used: usize,

        pub fn init(id: usize) Shape {
            var self = Shape{
                .id = id,
                .grid = undefined,
                .size = SHAPE_SIZE * SHAPE_SIZE,
                .used = 0,
            };
            for (0..SHAPE_SIZE) |r| {
                self.grid[r] = @splat('.');
            }
            return self;
        }

        pub fn setRow(self: *Shape, r: usize, str: []const u8) void {
            for (0..SHAPE_SIZE) |c| {
                self.grid[r][c] = str[c];
                if (str[c] == '#') self.used += 1;
            }
        }
    };

    const Board = struct {
        w: usize,
        h: usize,
        shapes: std.ArrayList(usize),

        pub fn init() Board {
            return .{
                .w = 0,
                .h = 0,
                .shapes = .empty,
            };
        }

        pub fn deinit(self: *Board, alloc: std.mem.Allocator) void {
            self.shapes.deinit(alloc);
        }

        pub fn getArea(self: Board) f32 {
            return @floatFromInt(self.w * self.h);
        }
    };

    alloc: std.mem.Allocator,
    shapes: std.ArrayList(Shape),
    boards: std.ArrayList(Board),

    pub fn init(alloc: std.mem.Allocator) Module {
        return .{
            .alloc = alloc,
            .shapes = .empty,
            .boards = .empty,
        };
    }

    pub fn deinit(self: *Module) void {
        for (self.boards.items) |*b| {
            b.deinit(self.alloc);
        }
        self.boards.deinit(self.alloc);
        self.shapes.deinit(self.alloc);
    }

    pub fn parseInput(self: *Module, data: []const u8) !void {
        var current_shape_row: usize = 0;
        var it_lines = std.mem.splitScalar(u8, data, '\n');
        while (it_lines.next()) |line| {
            if (line.len == 0) {
                std.debug.assert(current_shape_row == SHAPE_SIZE);
                continue;
            }

            if (line[line.len - 1] == ':') {
                const id = try std.fmt.parseUnsigned(usize, line[0 .. line.len - 1], 10);
                std.debug.assert(self.shapes.items.len == id);

                try self.shapes.append(self.alloc, Shape.init(id));
                current_shape_row = 0;
                continue;
            }

            if (std.ascii.isDigit(line[0])) {
                var board = Board.init();
                var pos: usize = 0;
                var it = std.mem.tokenizeAny(u8, line, ": ");
                while (it.next()) |chunk| : (pos += 1) {
                    if (pos > 0) {
                        const num = try std.fmt.parseUnsigned(usize, chunk, 10);
                        try board.shapes.append(self.alloc, num);
                        continue;
                    }
                    const x_pos = std.mem.indexOf(u8, chunk, "x").?;
                    board.w = try std.fmt.parseUnsigned(usize, chunk[0..x_pos], 10);
                    board.h = try std.fmt.parseUnsigned(usize, chunk[x_pos + 1 ..], 10);
                }
                try self.boards.append(self.alloc, board);
                continue;
            }

            const shape: *Shape = &self.shapes.items[self.shapes.items.len - 1];
            shape.setRow(current_shape_row, line);
            current_shape_row += 1;
        }
    }

    pub fn show(self: Module) void {
        std.debug.print("Module with {} shapes and {} boards\n", .{
            self.shapes.items.len,
            self.boards.items.len,
        });
        for (0..self.shapes.items.len) |s| {
            const shape = self.shapes.items[s];
            std.debug.print("Shape #{} id {} ({}/{}):\n", .{ s, shape.id, shape.used, shape.size });
            for (0..SHAPE_SIZE) |r| {
                std.debug.print("{s}\n", .{shape.grid[r][0..SHAPE_SIZE]});
            }
        }
        for (0..self.boards.items.len) |b| {
            const board = self.boards.items[b];
            std.debug.print("Board #{}: {}x{} -", .{ b, board.w, board.h });
            for (board.shapes.items) |s| {
                std.debug.print(" {}", .{s});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn countViableRegions(self: *Module) !usize {
        const heuristic = self.computeHeuristicFactor();
        var count: usize = 0;
        for (self.boards.items) |board| {
            // enlarge real board area with a heuristic factor
            const board_area = board.getArea() * heuristic;
            var needed_area: f32 = 0;
            for (0..board.shapes.items.len) |s| {
                const shape = self.shapes.items[s];
                const num_shapes = board.shapes.items[s];
                needed_area += @floatFromInt(num_shapes * shape.used);
            }
            if (needed_area > board_area) continue;
            count += 1;
        }
        return count;
    }

    fn computeHeuristicFactor(self: Module) f32 {
        // heuristic factor is a bit more of
        // the sum of the fraction of used space by each shape
        var size: usize = 0;
        var used: usize = 0;
        for (self.shapes.items) |shape| {
            size += shape.size;
            used += shape.used;
        }
        var factor: f32 = 1.0;
        factor *= @floatFromInt(used);
        factor /= @floatFromInt(size);
        factor *= HEURISTIC_FACTOR;
        return factor;
    }
};

test "sample part 1" {
    const data =
        \\0:
        \\###
        \\##.
        \\##.
        \\
        \\1:
        \\###
        \\##.
        \\.##
        \\
        \\2:
        \\.##
        \\###
        \\##.
        \\
        \\3:
        \\##.
        \\###
        \\##.
        \\
        \\4:
        \\###
        \\#..
        \\###
        \\
        \\5:
        \\###
        \\.#.
        \\###
        \\
        \\4x4: 0 0 0 0 2 0
        \\12x5: 1 0 1 0 2 2
        \\12x5: 1 0 1 0 3 2
    ;

    // 6 shapes, both in example and real data
    // All shapes are 3x3
    //   Example: 7+7+7+7+7+7 = 42
    // Real Data: 7+7+7+7+5+6 = 39

    var module = Module.init(testing.allocator);
    defer module.deinit();
    try module.parseInput(data);
    // module.show();

    const product = try module.countViableRegions();
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, product);
}
