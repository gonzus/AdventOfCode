const std = @import("std");
const testing = std.testing;

const allocator = std.heap.page_allocator;

pub const Map = struct {
    const SIZE = 100;

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            var self = Pos{
                .x = x,
                .y = y,
            };
            return self;
        }
    };

    pub const Tile = struct {
        id: usize,
        data: [SIZE][SIZE]u8,
        size: Pos,
        borders: [4]usize,

        pub fn init() Tile {
            var self = Tile{
                .id = 0,
                .data = undefined,
                .size = Pos.init(0, 0),
                .borders = undefined,
            };
            return self;
        }

        pub fn deinit(self: *Tile) void {}

        pub fn set(self: *Tile, data: []const u8) void {
            var it = std.mem.split(data, "\n");
            while (it.next()) |line| {
                for (line) |c, j| {
                    const t = if (c == '.') '.' else c;
                    self.data[j][self.size.y] = t;
                    if (self.size.y == 0) self.size.x += 1;
                }
                self.size.y += 1;
            }
            self.compute_borders();
        }

        pub fn show(self: Tile) void {
            if (self.id <= 0) {
                std.debug.warn("Image {} x {}\n", .{ self.size.x, self.size.y });
            } else {
                std.debug.warn("Tile id {}, {} x {}, borders", .{ self.id, self.size.x, self.size.y });
                var b: usize = 0;
                while (b < 4) : (b += 1) {
                    std.debug.warn(" {}", .{self.borders[b]});
                }
                std.debug.warn("\n", .{});
            }

            var y: usize = 0;
            while (y < self.size.y) : (y += 1) {
                var x: usize = 0;
                while (x < self.size.x) : (x += 1) {
                    std.debug.warn("{c}", .{self.data[x][y]});
                }
                std.debug.warn("\n", .{});
            }
        }

        fn mask_row(self: *Tile, row: usize) usize {
            var mask: usize = 0;
            var p: usize = 0;
            while (p < self.size.x) : (p += 1) {
                const what = self.data[p][row];
                const bit = if (what == '#' or what == 'X') @as(u1, 1) else @as(u1, 0);
                mask <<= @as(u1, 1);
                mask |= bit;
            }
            return mask;
        }

        fn mask_col(self: *Tile, col: usize) usize {
            var mask: usize = 0;
            var p: usize = 0;
            while (p < self.size.y) : (p += 1) {
                const what = self.data[col][p];
                const bit = if (what == '#' or what == 'X') @as(u1, 1) else @as(u1, 0);
                mask <<= @as(u1, 1);
                mask |= bit;
            }
            return mask;
        }

        fn compute_borders(self: *Tile) void {
            if (self.id <= 0) return;
            self.borders[0] = self.mask_row(0);
            self.borders[1] = self.mask_col(9);
            self.borders[2] = self.mask_row(9);
            self.borders[3] = self.mask_col(0);
        }

        pub fn rotate_right(self: *Tile) void {
            var data = self.data;
            var y: usize = 0;
            while (y < self.size.y) : (y += 1) {
                var x: usize = 0;
                while (x < self.size.x) : (x += 1) {
                    self.data[self.size.y - 1 - y][x] = data[x][y];
                }
            }
            const t = self.size.y;
            self.size.y = self.size.x;
            self.size.x = t;
            self.compute_borders();
        }

        pub fn reflect_horizontal(self: *Tile) void {
            var data = self.data;
            var y: usize = 0;
            while (y < self.size.y) : (y += 1) {
                var x: usize = 0;
                while (x < self.size.x) : (x += 1) {
                    self.data[x][y] = data[x][self.size.y - 1 - y];
                }
            }
            self.compute_borders();
        }

        pub fn reflect_vertical(self: *Tile) void {
            var data = self.data;
            var y: usize = 0;
            while (y < self.size.y) : (y += 1) {
                var x: usize = 0;
                while (x < self.size.x) : (x += 1) {
                    self.data[x][y] = data[self.size.x - 1 - x][y];
                }
            }
            self.compute_borders();
        }
    };

    const Grid = struct {
        tiles: std.AutoHashMap(Pos, usize), // pos => tile id
        min: Pos,
        max: Pos,
        data: [SIZE][SIZE]u8,
        size: Pos,

        pub fn init() Grid {
            var self = Grid{
                .tiles = std.AutoHashMap(Pos, usize).init(allocator),
                .min = Pos.init(std.math.maxInt(usize), std.math.maxInt(usize)),
                .max = Pos.init(0, 0),
                .data = undefined,
                .size = Pos.init(0, 0),
            };
            return self;
        }

        pub fn deinit(self: *Grid) void {
            self.tiles.deinit();
        }

        pub fn put(self: *Grid, pos: Pos, id: usize) void {
            _ = self.tiles.put(pos, id) catch unreachable;
            if (self.min.x > pos.x) self.min.x = pos.x;
            if (self.min.y > pos.y) self.min.y = pos.y;
            if (self.max.x < pos.x) self.max.x = pos.x;
            if (self.max.y < pos.y) self.max.y = pos.y;
        }

        pub fn show(self: Grid) void {
            std.debug.warn("Grid {} x {}\n", .{ self.size.x, self.size.y });
            var y: usize = 0;
            while (y < self.size.y) : (y += 1) {
                var x: usize = 0;
                while (x < self.size.x) : (x += 1) {
                    std.debug.warn("{c}", .{self.data[x][y]});
                }
                std.debug.warn("\n", .{});
            }
        }
    };

    tiles: std.AutoHashMap(usize, Tile),
    tile_size: Pos,
    size: usize,
    grid: Grid,
    current_tile: Tile,

    pub fn init() Map {
        var self = Map{
            .tiles = std.AutoHashMap(usize, Tile).init(allocator),
            .tile_size = Pos.init(0, 0),
            .size = 0,
            .grid = Grid.init(),
            .current_tile = Tile.init(),
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.grid.deinit();
        self.tiles.deinit();
    }

    pub fn add_line(self: *Map, line: []const u8) void {
        if (line.len == 0) {
            self.current_tile = Tile.init();
            return;
        }

        if (line[0] == 'T') {
            var it = std.mem.tokenize(line, " :");
            _ = it.next().?;
            self.current_tile.id = std.fmt.parseInt(usize, it.next().?, 10) catch unreachable;
            return;
        }

        for (line) |c, j| {
            self.current_tile.data[j][self.current_tile.size.y] = c;
            if (self.current_tile.size.y == 0) self.current_tile.size.x += 1;
        }
        self.current_tile.size.y += 1;
        if (self.current_tile.size.y == self.current_tile.size.x) {
            self.current_tile.compute_borders();
            _ = self.tiles.put(self.current_tile.id, self.current_tile) catch unreachable;
            if (self.tile_size.x <= 0 or self.tile_size.y <= 0) {
                self.tile_size.x = self.current_tile.size.x;
                self.tile_size.y = self.current_tile.size.y;
            } else if (self.tile_size.x != self.current_tile.size.x or self.tile_size.y != self.current_tile.size.y) {
                @panic("JAGGED");
            }
        }
    }

    pub fn show(self: *Map) void {
        std.debug.warn("Map with {} tiles\n", .{self.tiles.count()});
        var it = self.tiles.iterator();
        while (it.next()) |kv| {
            kv.value.show();
        }
    }

    pub fn find_layout(self: *Map) void {
        self.grid.tiles.clearRetainingCapacity();

        var pending = std.AutoHashMap(Pos, void).init(allocator);
        defer pending.deinit();
        var used = std.AutoHashMap(usize, void).init(allocator);
        defer used.deinit();

        _ = pending.put(Pos.init(1000, 1000), {}) catch unreachable;
        while (true) {
            if (self.grid.tiles.count() == self.tiles.count()) break; // all tiles placed

            // std.debug.warn("CHECKING GRID, tiles {}, placed {}, pending empties {}\n", .{ self.tiles.count(), self.grid.tiles.count(), pending.count() });

            var empty = true;
            var pos: Pos = undefined;
            var itp = pending.iterator();
            while (itp.next()) |kvp| {
                pos = kvp.key;
                empty = false;
                _ = pending.remove(pos);
                break;
            }
            if (empty) break; // no pending empty positions

            var itt = self.tiles.iterator();
            while (itt.next()) |kvt| {
                var tile = &kvt.value;
                if (used.contains(tile.id)) continue; // tile already placed

                const posU = Pos.init(pos.x - 0, pos.y - 1);
                const entryU = self.grid.tiles.getEntry(posU);
                const posD = Pos.init(pos.x - 0, pos.y + 1);
                const entryD = self.grid.tiles.getEntry(posD);
                const posL = Pos.init(pos.x - 1, pos.y - 0);
                const entryL = self.grid.tiles.getEntry(posL);
                const posR = Pos.init(pos.x + 1, pos.y - 0);
                const entryR = self.grid.tiles.getEntry(posR);

                // check if tile fits in pos
                var fits = true;
                if (entryU) |e| fits = fits and self.fits_neighbor(tile, e.value, 0);
                if (entryD) |e| fits = fits and self.fits_neighbor(tile, e.value, 2);
                if (entryL) |e| fits = fits and self.fits_neighbor(tile, e.value, 3);
                if (entryR) |e| fits = fits and self.fits_neighbor(tile, e.value, 1);
                if (!fits) continue; // tile did not fit in

                // std.debug.warn("MATCH {} for pos {}\n", .{ tile.id, pos });
                // tile.show();
                self.grid.put(pos, tile.id); // put tile in grid
                _ = used.put(tile.id, {}) catch unreachable; // remember tile as used

                // add four neighbors to pending, if they are empty
                if (entryU) |e| {} else {
                    _ = pending.put(posU, {}) catch unreachable;
                }
                if (entryD) |e| {} else {
                    _ = pending.put(posD, {}) catch unreachable;
                }
                if (entryL) |e| {} else {
                    _ = pending.put(posL, {}) catch unreachable;
                }
                if (entryR) |e| {} else {
                    _ = pending.put(posR, {}) catch unreachable;
                }
                break;
            }
        }

        // std.debug.warn("Found correct layout: {} {} - {} {}\n", .{ self.grid.min.x, self.grid.min.y, self.grid.max.x, self.grid.max.y });
        var gy: usize = self.grid.min.y;
        while (gy <= self.grid.max.y) : (gy += 1) {
            var gx: usize = self.grid.min.x;
            while (gx <= self.grid.max.x) : (gx += 1) {
                const pos = Pos.init(gx, gy);
                const id = self.grid.tiles.get(pos).?;
                const tile = self.tiles.get(id).?;
                // std.debug.warn(" {}", .{id});

                var py = (gy - self.grid.min.y) * (self.tile_size.y - 2);
                var ty: usize = 0;
                while (ty < self.tile_size.y) : (ty += 1) {
                    var px = (gx - self.grid.min.x) * (self.tile_size.x - 2);
                    if (ty == 0 or ty == self.tile_size.y - 1) continue;
                    var tx: usize = 0;
                    while (tx < self.tile_size.x) : (tx += 1) {
                        if (tx == 0 or tx == self.tile_size.x - 1) continue;
                        // std.debug.warn("DATA {} {} = TILE {} {}\n", .{ px, py, tx, ty });
                        self.grid.data[px][py] = tile.data[tx][ty];
                        px += 1;
                    }
                    py += 1;
                }
            }
            // std.debug.warn("\n", .{});
        }

        self.grid.size = Pos.init(
            (self.tile_size.x - 2) * (self.grid.max.x - self.grid.min.x + 1),
            (self.tile_size.y - 2) * (self.grid.max.y - self.grid.min.y + 1),
        );
        // self.grid.show();
    }

    // TODO: should not always rotate tile; only the first time?
    fn fits_neighbor(self: *Map, tile: *Tile, fixed_id: usize, dir: usize) bool {
        const fixed_tile = self.tiles.get(fixed_id).?;
        const fixed_dir = (dir + 2) % 4;
        const fixed_border = fixed_tile.borders[fixed_dir];
        // std.debug.warn("FITS CHECK tile {} dir {} and fixed {} dir {} = {}\n", .{ tile.id, dir, fixed_id, fixed_dir, fixed_border });
        var op: usize = 0;
        while (op < 13) : (op += 1) {
            switch (op) {
                0 => {},
                1 => {
                    tile.reflect_horizontal();
                },
                2 => {
                    tile.reflect_horizontal();
                    tile.reflect_vertical();
                },
                3 => {
                    tile.reflect_vertical();
                    tile.rotate_right();
                },
                4 => {
                    tile.reflect_horizontal();
                },
                5 => {
                    tile.reflect_horizontal();
                    tile.reflect_vertical();
                },
                6 => {
                    tile.reflect_vertical();
                    tile.rotate_right();
                },
                7 => {
                    tile.reflect_horizontal();
                },
                8 => {
                    tile.reflect_horizontal();
                    tile.reflect_vertical();
                },
                9 => {
                    tile.reflect_vertical();
                    tile.rotate_right();
                },
                10 => {
                    tile.reflect_horizontal();
                },
                11 => {
                    tile.reflect_horizontal();
                    tile.reflect_vertical();
                },
                12 => {
                    tile.reflect_vertical();
                    tile.rotate_right();
                },
                else => @panic("OP"),
            }
            // tile.show();
            const tile_border = tile.borders[dir];
            const fits = tile_border == fixed_border;
            // std.debug.warn("  border {}, fixed {}: {}\n", .{ tile_border, fixed_border, fits });
            if (fits) return true;
        }
        return false;
    }

    pub fn product_four_corners(self: *Map) usize {
        var product: usize = 1;
        var id: usize = 0;

        product *= self.grid.tiles.get(Pos.init(self.grid.min.x, self.grid.min.y)).?;
        product *= self.grid.tiles.get(Pos.init(self.grid.min.x, self.grid.max.y)).?;
        product *= self.grid.tiles.get(Pos.init(self.grid.max.x, self.grid.min.y)).?;
        product *= self.grid.tiles.get(Pos.init(self.grid.max.x, self.grid.max.y)).?;
        return product;
    }

    pub fn find_image_in_grid(self: *Map, image: *Tile) usize {
        var total_found: usize = 0;
        var total_roughness: usize = 0;
        var counts: [SIZE][SIZE]usize = undefined;
        {
            var y: usize = 0;
            while (y < self.grid.size.y) : (y += 1) {
                var x: usize = 0;
                while (x < self.grid.size.y) : (x += 1) {
                    counts[x][y] = 0;
                    if (self.grid.data[x][y] == '.') continue;
                    counts[x][y] = 1;
                    total_roughness += 1;
                }
            }
        }
        // std.debug.warn("Searching image {} x {} in grid {} x {} (initial roughness {})\n", .{ image.size.x, image.size.y, self.grid.size.x, self.grid.size.y, total_roughness });

        var op: usize = 0;
        while (op < 13) : (op += 1) {
            switch (op) {
                0 => {},
                1 => {
                    image.reflect_horizontal();
                },
                2 => {
                    image.reflect_horizontal();
                    image.reflect_vertical();
                },
                3 => {
                    image.reflect_vertical();
                    image.rotate_right();
                },
                4 => {
                    image.reflect_horizontal();
                },
                5 => {
                    image.reflect_horizontal();
                    image.reflect_vertical();
                },
                6 => {
                    image.reflect_vertical();
                    image.rotate_right();
                },
                7 => {
                    image.reflect_horizontal();
                },
                8 => {
                    image.reflect_horizontal();
                    image.reflect_vertical();
                },
                9 => {
                    image.reflect_vertical();
                    image.rotate_right();
                },
                10 => {
                    image.reflect_horizontal();
                },
                11 => {
                    image.reflect_horizontal();
                    image.reflect_vertical();
                },
                12 => {
                    image.reflect_vertical();
                    image.rotate_right();
                },
                else => @panic("OP"),
            }
            // std.debug.warn("CURRENT IMAGE {} x {}\n", .{ image.size.x, image.size.y });
            var y: usize = 0;
            while (y < self.grid.size.y) : (y += 1) {
                if (y + image.size.y >= self.grid.size.y) break;
                var x: usize = 0;
                while (x < self.grid.size.x) : (x += 1) {
                    if (x + image.size.x >= self.grid.size.y) break;

                    // std.debug.warn("CORNER {} {}\n", .{ x, y });
                    var found = true;
                    var iy: usize = 0;
                    IMAGE: while (iy < image.size.y) : (iy += 1) {
                        var ix: usize = 0;
                        while (ix < image.size.x) : (ix += 1) {
                            if (image.data[ix][iy] == '.') continue;
                            if (self.grid.data[x + ix][y + iy] == '.') {
                                found = false;
                                break :IMAGE;
                            }
                        }
                    }
                    if (!found) continue;

                    total_found += 1;
                    iy = 0;
                    while (iy < image.size.y) : (iy += 1) {
                        var ix: usize = 0;
                        while (ix < image.size.x) : (ix += 1) {
                            if (image.data[ix][iy] == '.') continue;
                            counts[x + ix][y + iy] = 0;
                            self.grid.data[x + ix][y + iy] = 'O';
                        }
                    }
                }
            }
        }

        total_roughness = 0;
        {
            var y: usize = 0;
            while (y < self.grid.size.y) : (y += 1) {
                var x: usize = 0;
                while (x < self.grid.size.x) : (x += 1) {
                    total_roughness += counts[x][y];
                }
            }
        }
        // std.debug.warn("Searched image and found {} copies, total roughness {}\n", .{ total_found, total_roughness });
        // self.grid.show();
        return total_roughness;
    }
};

test "sample part a" {
    const data: []const u8 =
        \\Tile 2311:
        \\..##.#..#.
        \\##..#.....
        \\#...##..#.
        \\####.#...#
        \\##.##.###.
        \\##...#.###
        \\.#.#.#..##
        \\..#....#..
        \\###...#.#.
        \\..###..###
        \\
        \\Tile 1951:
        \\#.##...##.
        \\#.####...#
        \\.....#..##
        \\#...######
        \\.##.#....#
        \\.###.#####
        \\###.##.##.
        \\.###....#.
        \\..#.#..#.#
        \\#...##.#..
        \\
        \\Tile 1171:
        \\####...##.
        \\#..##.#..#
        \\##.#..#.#.
        \\.###.####.
        \\..###.####
        \\.##....##.
        \\.#...####.
        \\#.##.####.
        \\####..#...
        \\.....##...
        \\
        \\Tile 1427:
        \\###.##.#..
        \\.#..#.##..
        \\.#.##.#..#
        \\#.#.#.##.#
        \\....#...##
        \\...##..##.
        \\...#.#####
        \\.#.####.#.
        \\..#..###.#
        \\..##.#..#.
        \\
        \\Tile 1489:
        \\##.#.#....
        \\..##...#..
        \\.##..##...
        \\..#...#...
        \\#####...#.
        \\#..#.#.#.#
        \\...#.#.#..
        \\##.#...##.
        \\..##.##.##
        \\###.##.#..
        \\
        \\Tile 2473:
        \\#....####.
        \\#..#.##...
        \\#.##..#...
        \\######.#.#
        \\.#...#.#.#
        \\.#########
        \\.###.#..#.
        \\########.#
        \\##...##.#.
        \\..###.#.#.
        \\
        \\Tile 2971:
        \\..#.#....#
        \\#...###...
        \\#.#.###...
        \\##.##..#..
        \\.#####..##
        \\.#..####.#
        \\#..#.#..#.
        \\..####.###
        \\..#.#.###.
        \\...#.#.#.#
        \\
        \\Tile 2729:
        \\...#.#.#.#
        \\####.#....
        \\..#.#.....
        \\....#..#.#
        \\.##..##.#.
        \\.#.####...
        \\####.#.#..
        \\##.####...
        \\##..#.##..
        \\#.##...##.
        \\
        \\Tile 3079:
        \\#.#.#####.
        \\.#..######
        \\..#.......
        \\######....
        \\####.#..#.
        \\.#...#.##.
        \\#.#####.##
        \\..#.###...
        \\..#.......
        \\..#.###...
    ;

    var map = Map.init();
    defer map.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        map.add_line(line);
    }
    // map.show();

    map.find_layout();

    const product = map.product_four_corners();
    testing.expect(product == 20899048083289);
}

test "sample part b" {
    const data: []const u8 =
        \\Tile 2311:
        \\..##.#..#.
        \\##..#.....
        \\#...##..#.
        \\####.#...#
        \\##.##.###.
        \\##...#.###
        \\.#.#.#..##
        \\..#....#..
        \\###...#.#.
        \\..###..###
        \\
        \\Tile 1951:
        \\#.##...##.
        \\#.####...#
        \\.....#..##
        \\#...######
        \\.##.#....#
        \\.###.#####
        \\###.##.##.
        \\.###....#.
        \\..#.#..#.#
        \\#...##.#..
        \\
        \\Tile 1171:
        \\####...##.
        \\#..##.#..#
        \\##.#..#.#.
        \\.###.####.
        \\..###.####
        \\.##....##.
        \\.#...####.
        \\#.##.####.
        \\####..#...
        \\.....##...
        \\
        \\Tile 1427:
        \\###.##.#..
        \\.#..#.##..
        \\.#.##.#..#
        \\#.#.#.##.#
        \\....#...##
        \\...##..##.
        \\...#.#####
        \\.#.####.#.
        \\..#..###.#
        \\..##.#..#.
        \\
        \\Tile 1489:
        \\##.#.#....
        \\..##...#..
        \\.##..##...
        \\..#...#...
        \\#####...#.
        \\#..#.#.#.#
        \\...#.#.#..
        \\##.#...##.
        \\..##.##.##
        \\###.##.#..
        \\
        \\Tile 2473:
        \\#....####.
        \\#..#.##...
        \\#.##..#...
        \\######.#.#
        \\.#...#.#.#
        \\.#########
        \\.###.#..#.
        \\########.#
        \\##...##.#.
        \\..###.#.#.
        \\
        \\Tile 2971:
        \\..#.#....#
        \\#...###...
        \\#.#.###...
        \\##.##..#..
        \\.#####..##
        \\.#..####.#
        \\#..#.#..#.
        \\..####.###
        \\..#.#.###.
        \\...#.#.#.#
        \\
        \\Tile 2729:
        \\...#.#.#.#
        \\####.#....
        \\..#.#.....
        \\....#..#.#
        \\.##..##.#.
        \\.#.####...
        \\####.#.#..
        \\##.####...
        \\##..#.##..
        \\#.##...##.
        \\
        \\Tile 3079:
        \\#.#.#####.
        \\.#..######
        \\..#.......
        \\######....
        \\####.#..#.
        \\.#...#.##.
        \\#.#####.##
        \\..#.###...
        \\..#.......
        \\..#.###...
    ;

    const dragon: []const u8 =
        \\..................#.
        \\#....##....##....###
        \\.#..#..#..#..#..#...
    ;

    var image = Map.Tile.init();
    defer image.deinit();
    image.set(dragon);
    // image.show();

    var map = Map.init();
    defer map.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        map.add_line(line);
    }
    // map.show();

    map.find_layout();

    const roughness = map.find_image_in_grid(&image);
    testing.expect(roughness == 273);
}
