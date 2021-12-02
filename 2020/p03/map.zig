const std = @import("std");
const testing = std.testing;

pub const Map = struct {
    rows: usize,
    cols: usize,
    cells: std.AutoHashMap(Pos, Tile),

    pub const Tile = enum(u8) {
        Empty = 0,
        Tree = 1,
    };

    pub const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            return Pos{
                .x = x,
                .y = y,
            };
        }
    };

    pub fn init() Map {
        const allocator = std.heap.page_allocator;
        var self = Map{
            .rows = 0,
            .cols = 0,
            .cells = std.AutoHashMap(Pos, Tile).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.cells.deinit();
    }

    pub fn add_line(self: *Map, line: []const u8) void {
        if (self.cols == 0) {
            self.cols = line.len;
        }
        if (self.cols != line.len) {
            @panic("jagged map");
        }
        var x: usize = 0;
        while (x < self.cols) : (x += 1) {
            if (line[x] != '#') continue;
            const pos = Pos.init(x, self.rows);
            _ = self.cells.put(pos, Map.Tile.Tree) catch unreachable;
        }
        self.rows += 1;
    }

    pub fn traverse(self: Map, right: usize, down: usize) usize {
        var pos = Pos.init(0, 0);
        var count: usize = 0;
        while (pos.y < self.rows) {
            const found = self.cells.get(pos);
            if (found) |t| {
                if (t == Tile.Tree) {
                    // std.debug.warn("TREE {}x{}\n", .{ pos.x, pos.y });
                    count += 1;
                }
            }
            // TODO: can zig do the add and mod in one go?
            pos.x += right;
            pos.x %= self.cols;
            pos.y += down;
        }
        return count;
    }

    pub fn traverse_several(self: Map, specs: []const [2]usize) usize {
        var product: usize = 1;
        for (specs) |spec| {
            product *= self.traverse(spec[0], spec[1]);
        }
        return product;
    }

    pub fn show(self: Map) void {
        std.debug.warn("MAP: {} x {}\n", .{ self.rows, self.cols });
        var y: usize = 0;
        while (y < self.rows) : (y += 1) {
            std.debug.warn("{:4} | ", .{y});
            var x: usize = 0;
            while (x < self.cols) : (x += 1) {
                var tile: u8 = '.';
                const pos = Pos.init(x, y);
                const found = self.cells.get(pos);
                if (found) |t| {
                    switch (t) {
                        Tile.Empty => tile = '.',
                        Tile.Tree => tile = '#',
                    }
                }
                std.debug.warn("{c}", .{tile});
            }
            std.debug.warn("\n", .{});
        }
    }
};

test "sample single" {
    const data: []const u8 =
        \\..##.......
        \\#...#...#..
        \\.#....#..#.
        \\..#.#...#.#
        \\.#...##..#.
        \\..#.##.....
        \\.#.#.#....#
        \\.#........#
        \\#.##...#...
        \\#...##....#
        \\.#..#...#.#
    ;

    var map = Map.init();
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        map.add_line(line);
    }
    // map.show();

    const count = map.traverse(3, 1);
    try testing.expect(count == 7);
}

test "sample several" {
    const data: []const u8 =
        \\..##.......
        \\#...#...#..
        \\.#....#..#.
        \\..#.#...#.#
        \\.#...##..#.
        \\..#.##.....
        \\.#.#.#....#
        \\.#........#
        \\#.##...#...
        \\#...##....#
        \\.#..#...#.#
    ;

    var map = Map.init();
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        map.add_line(line);
    }
    // map.show();

    const specs = [_][2]usize{
        [_]usize{ 1, 1 },
        [_]usize{ 3, 1 },
        [_]usize{ 5, 1 },
        [_]usize{ 7, 1 },
        [_]usize{ 1, 2 },
    };

    const product = map.traverse_several(specs[0..]);
    try testing.expect(product == 336);
}
