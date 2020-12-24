const std = @import("std");
const testing = std.testing;

const allocator = std.heap.page_allocator;

pub const Map = struct {
    const Color = enum {
        White,
        Black,

        pub fn flip(color: Color) Color {
            return switch (color) {
                Color.White => Color.Black,
                Color.Black => Color.White,
            };
        }
    };

    const Dir = enum {
        E,
        SE,
        SW,
        W,
        NW,
        NE,
    };

    // These are Cube Coordinates in a hexagonal grid.
    // Basically a 3D coordinate system with one additional restriction:
    //
    //   x + y + z = 0
    //
    // This makes it into an effective way of representing the hex grid on a 2D
    // surface.
    // https://www.redblobgames.com/grids/hexagons/
    const Pos = struct {
        x: isize,
        y: isize,
        z: isize,

        pub fn init(x: isize, y: isize, z: isize) Pos {
            var self = Pos{
                .x = x,
                .y = y,
                .z = z,
            };
            return self;
        }

        pub fn is_valid(self: Pos) bool {
            return self.x + self.y + self.z == 0;
        }

        pub fn move(self: *Pos, dir: Dir) void {
            // Notice how the hex invariant is maintained in each case, since
            // we always add 1 and subtract 1.
            switch (dir) {
                Dir.E => {
                    self.x += 1;
                    self.y += -1;
                    self.z += 0;
                },
                Dir.SE => {
                    self.x += 0;
                    self.y += -1;
                    self.z += 1;
                },
                Dir.SW => {
                    self.x += -1;
                    self.y += 0;
                    self.z += 1;
                },
                Dir.W => {
                    self.x += -1;
                    self.y += 1;
                    self.z += 0;
                },
                Dir.NW => {
                    self.x += 0;
                    self.y += 1;
                    self.z += -1;
                },
                Dir.NE => {
                    self.x += 1;
                    self.y += 0;
                    self.z += -1;
                },
            }
        }
    };

    min: Pos,
    max: Pos,
    tiles: [2]std.AutoHashMap(Pos, Color),
    curr: usize,

    pub fn init() Map {
        var self = Map{
            .min = Pos.init(std.math.maxInt(isize), std.math.maxInt(isize), std.math.maxInt(isize)),
            .max = Pos.init(std.math.minInt(isize), std.math.minInt(isize), std.math.minInt(isize)),
            .tiles = undefined,
            .curr = 0,
        };
        self.tiles[0] = std.AutoHashMap(Pos, Color).init(allocator);
        self.tiles[1] = std.AutoHashMap(Pos, Color).init(allocator);
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.tiles[1].deinit();
        self.tiles[0].deinit();
    }

    pub fn process_tile(self: *Map, line: []const u8) void {
        // std.debug.warn("TILE [{}]\n", .{line});
        var pos = Pos.init(0, 0, 0);
        var p: u8 = 0;
        for (line) |c| {
            // std.debug.warn(" c [{c}]\n", .{c});
            switch (c) {
                'e' => {
                    switch (p) {
                        0 => pos.move(Dir.E),
                        'n' => pos.move(Dir.NE),
                        's' => pos.move(Dir.SE),
                        else => @panic("E"),
                    }
                    p = 0;
                },
                'w' => {
                    switch (p) {
                        0 => pos.move(Dir.W),
                        'n' => pos.move(Dir.NW),
                        's' => pos.move(Dir.SW),
                        else => @panic("W"),
                    }
                    p = 0;
                },
                's' => p = c,
                'n' => p = c,
                else => @panic("DIR"),
            }
        }

        const current = self.get_color(pos);
        const next = current.flip();
        // std.debug.warn("FLIP {} -> {}\n", .{ current, next });
        _ = self.tiles[self.curr].put(pos, next) catch unreachable;

        self.update_bounday(pos);
    }

    pub fn get_color(self: Map, pos: Pos) Color {
        return if (self.tiles[self.curr].contains(pos)) self.tiles[self.curr].get(pos).? else Color.White;
    }

    pub fn count_black(self: Map) usize {
        return self.count_color(Color.Black);
    }

    fn count_color(self: Map, color: Color) usize {
        var count: usize = 0;
        var it = self.tiles[self.curr].iterator();
        while (it.next()) |kv| {
            if (kv.value != color) continue;
            count += 1;
        }
        return count;
    }

    pub fn run(self: *Map, turns: usize) void {
        var t: usize = 0;
        while (t < turns) : (t += 1) {
            // if (t % 10 == 0) std.debug.warn("Run {}/{}\n", .{ t, turns });
            self.step();
        }
    }

    fn update_bounday(self: *Map, pos: Pos) void {
        if (self.min.x > pos.x) self.min.x = pos.x;
        if (self.min.y > pos.y) self.min.y = pos.y;
        if (self.min.z > pos.z) self.min.z = pos.z;
        if (self.max.x < pos.x) self.max.x = pos.x;
        if (self.max.y < pos.y) self.max.y = pos.y;
        if (self.max.z < pos.z) self.max.z = pos.z;
    }

    fn step(self: *Map) void {
        var ops: usize = 0;
        var next = 1 - self.curr;
        const min = self.min;
        const max = self.max;
        // std.debug.warn("STEP {} {}\n", .{ min, max });
        var z: isize = min.z - 1;
        while (z <= max.z + 1) : (z += 1) {
            var y: isize = min.y - 1;
            while (y <= max.y + 1) : (y += 1) {
                var x: isize = min.x - 1;
                while (x <= max.x + 1) : (x += 1) {
                    const pos = Pos.init(x, y, z);
                    if (!pos.is_valid()) continue;
                    _ = self.tiles[next].remove(pos);
                    const adjacent = self.count_adjacent(pos);
                    const color = self.get_color(pos);
                    var new = color;
                    switch (color) {
                        Color.Black => {
                            if (adjacent == 0 or adjacent > 2) new = color.flip();
                        },
                        Color.White => {
                            if (adjacent == 2) new = color.flip();
                        },
                    }
                    _ = self.tiles[next].put(pos, new) catch unreachable;
                    self.update_bounday(pos);
                    ops += 1;
                }
            }
        }
        self.curr = next;
        // std.debug.warn("OPS: {}\n", .{ops});
    }

    fn count_adjacent(self: Map, pos: Pos) usize {
        var count: usize = 0;
        var c: usize = 0;
        while (c < 6) : (c += 1) {
            var neighbor = pos;
            switch (c) {
                0 => neighbor.move(Dir.E),
                1 => neighbor.move(Dir.SE),
                2 => neighbor.move(Dir.SW),
                3 => neighbor.move(Dir.W),
                4 => neighbor.move(Dir.NW),
                5 => neighbor.move(Dir.NE),
                else => @panic("ADJACENT"),
            }
            const color = self.get_color(neighbor);
            if (color != Color.Black) continue;
            count += 1;
        }
        return count;
    }
};

test "sample part a" {
    const data: []const u8 =
        \\sesenwnenenewseeswwswswwnenewsewsw
        \\neeenesenwnwwswnenewnwwsewnenwseswesw
        \\seswneswswsenwwnwse
        \\nwnwneseeswswnenewneswwnewseswneseene
        \\swweswneswnenwsewnwneneseenw
        \\eesenwseswswnenwswnwnwsewwnwsene
        \\sewnenenenesenwsewnenwwwse
        \\wenwwweseeeweswwwnwwe
        \\wsweesenenewnwwnwsenewsenwwsesesenwne
        \\neeswseenwwswnwswswnw
        \\nenwswwsewswnenenewsenwsenwnesesenew
        \\enewnwewneswsewnwswenweswnenwsenwsw
        \\sweneswneswneneenwnewenewwneswswnese
        \\swwesenesewenwneswnwwneseswwne
        \\enesenwswwswneneswsenwnewswseenwsese
        \\wnwnesenesenenwwnenwsewesewsesesew
        \\nenewswnwewswnenesenwnesewesw
        \\eneswnwswnwsenenwnwnwwseeswneewsenese
        \\neswnwewnwnwseenwseesewsenwsweewe
        \\wseweeenwnesenwwwswnew
    ;

    var map = Map.init();
    defer map.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        map.process_tile(line);
    }

    const black = map.count_black();
    testing.expect(black == 10);
}

test "sample part b" {
    const data: []const u8 =
        \\sesenwnenenewseeswwswswwnenewsewsw
        \\neeenesenwnwwswnenewnwwsewnenwseswesw
        \\seswneswswsenwwnwse
        \\nwnwneseeswswnenewneswwnewseswneseene
        \\swweswneswnenwsewnwneneseenw
        \\eesenwseswswnenwswnwnwsewwnwsene
        \\sewnenenenesenwsewnenwwwse
        \\wenwwweseeeweswwwnwwe
        \\wsweesenenewnwwnwsenewsenwwsesesenwne
        \\neeswseenwwswnwswswnw
        \\nenwswwsewswnenenewsenwsenwnesesenew
        \\enewnwewneswsewnwswenweswnenwsenwsw
        \\sweneswneswneneenwnewenewwneswswnese
        \\swwesenesewenwneswnwwneseswwne
        \\enesenwswwswneneswsenwnewswseenwsese
        \\wnwnesenesenenwwnenwsewesewsesesew
        \\nenewswnwewswnenesenwnesewesw
        \\eneswnwswnwsenenwnwnwwseeswneewsenese
        \\neswnwewnwnwseenwseesewsenwsweewe
        \\wseweeenwnesenwwwswnew
    ;

    var map = Map.init();
    defer map.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        map.process_tile(line);
    }

    testing.expect(map.count_black() == 10);

    map.run(1);
    testing.expect(map.count_black() == 15);
    map.run(1);
    testing.expect(map.count_black() == 12);
    map.run(1);
    testing.expect(map.count_black() == 25);
    map.run(1);
    testing.expect(map.count_black() == 14);
    map.run(1);
    testing.expect(map.count_black() == 23);
    map.run(1);
    testing.expect(map.count_black() == 28);
    map.run(1);
    testing.expect(map.count_black() == 41);
    map.run(1);
    testing.expect(map.count_black() == 37);
    map.run(1);
    testing.expect(map.count_black() == 49);
    map.run(1);
    testing.expect(map.count_black() == 37);

    map.run(10);
    testing.expect(map.count_black() == 132);
    map.run(10);
    testing.expect(map.count_black() == 259);
    map.run(10);
    testing.expect(map.count_black() == 406);
    map.run(10);
    testing.expect(map.count_black() == 566);
    map.run(10);
    testing.expect(map.count_black() == 788);
    map.run(10);
    testing.expect(map.count_black() == 1106);
    map.run(10);
    testing.expect(map.count_black() == 1373);
    map.run(10);
    testing.expect(map.count_black() == 1844);
    map.run(10);
    testing.expect(map.count_black() == 2208);
}
