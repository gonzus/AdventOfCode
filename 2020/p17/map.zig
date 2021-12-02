const std = @import("std");
const testing = std.testing;

const allocator = std.heap.page_allocator;

pub const Map = struct {
    const OFFSET = 1000;

    space: Space,
    min: Pos,
    max: Pos,
    cells: [2]std.AutoHashMap(Pos, Tile),
    curr: usize,
    next: usize,

    pub const Space = enum {
        Dim3,
        Dim4,
    };

    pub const Tile = enum {
        Active,
        Inactive,
    };

    pub const Pos = struct {
        x: usize,
        y: usize,
        z: usize,
        w: usize,

        pub fn init(x: usize, y: usize, z: usize, w: usize) Pos {
            return Pos{
                .x = x,
                .y = y,
                .z = z,
                .w = w,
            };
        }
    };

    pub fn init(space: Space) Map {
        var self = Map{
            .space = space,
            .min = Pos.init(OFFSET, OFFSET, OFFSET, OFFSET),
            .max = Pos.init(OFFSET, OFFSET, OFFSET, OFFSET),
            .cells = undefined,
            .curr = 0,
            .next = 1,
        };
        self.cells[0] = std.AutoHashMap(Pos, Tile).init(allocator);
        self.cells[1] = std.AutoHashMap(Pos, Tile).init(allocator);
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.cells[1].deinit();
        self.cells[0].deinit();
    }

    pub fn add_line(self: *Map, line: []const u8) void {
        if (self.max.x == OFFSET) {
            self.max.x = OFFSET + line.len;
        }
        if (self.max.x != OFFSET + line.len) {
            @panic("jagged map");
        }
        var x: usize = 0;
        while (x < self.max.x - OFFSET) : (x += 1) {
            const tile = switch (line[x]) {
                '#' => Tile.Active,
                '.' => Tile.Inactive,
                else => @panic("TILE"),
            };
            if (tile == Tile.Inactive) continue;
            const pos = Pos.init(OFFSET + x, self.max.y, OFFSET, OFFSET);
            _ = self.cells[self.curr].put(pos, tile) catch unreachable;
        }
        self.max.y += 1;
        if (self.max.z == OFFSET) self.max.z += 1;
        if (self.max.w == OFFSET) self.max.w += 1;
    }

    pub fn show(self: Map) void {
        std.debug.warn("MAP: {} x {} x {} x {} -- {} active\n", .{ self.max.x - self.min.x, self.max.y - self.min.y, self.max.z - self.min.z, self.max.w - self.min.w, self.count_active() });
        var w: usize = self.min.w;
        while (w < self.max.w) : (w += 1) {
            var z: usize = self.min.z;
            while (z < self.max.z) : (z += 1) {
                std.debug.warn("z={}, w={}\n", .{ z, w });
                var y: usize = self.min.y;
                while (y < self.max.y) : (y += 1) {
                    std.debug.warn("{:4} | ", .{y});
                    var x: usize = self.min.x;
                    while (x < self.max.x) : (x += 1) {
                        var label: u8 = '.';
                        const pos = Pos.init(x, y, z, w);
                        const found = self.cells[self.curr].get(pos);
                        if (found) |t| {
                            label = switch (t) {
                                Tile.Active => '#',
                                Tile.Inactive => '.',
                            };
                        }
                        std.debug.warn("{c}", .{label});
                    }
                    std.debug.warn("\n", .{});
                }
            }
        }
    }

    pub fn count_active(self: Map) usize {
        var count: usize = 0;
        var w: usize = self.min.w;
        while (w < self.max.w) : (w += 1) {
            var z: usize = self.min.z;
            while (z < self.max.z) : (z += 1) {
                var y: usize = self.min.y;
                while (y < self.max.y) : (y += 1) {
                    var x: usize = self.min.x;
                    while (x < self.max.x) : (x += 1) {
                        const pos = Pos.init(x, y, z, w);
                        if (!self.cells[self.curr].contains(pos)) continue;
                        const tile = self.cells[self.curr].get(pos).?;
                        if (tile != Tile.Active) continue;
                        count += 1;
                    }
                }
            }
        }
        return count;
    }

    pub fn run(self: *Map, cycles: usize) usize {
        var c: usize = 0;
        while (c < cycles) : (c += 1) {
            self.step();
        }
        return self.count_active();
    }

    pub fn step(self: *Map) void {
        var min: Pos = self.min;
        var max: Pos = self.max;
        var minw = self.min.w;
        var maxw = self.max.w;
        if (self.space == .Dim4) {
            minw -= 1;
            maxw += 1;
        }
        var w: usize = minw;
        while (w < maxw) : (w += 1) {
            var z: usize = self.min.z - 1;
            while (z < self.max.z + 1) : (z += 1) {
                var y: usize = self.min.y - 1;
                while (y < self.max.y + 1) : (y += 1) {
                    var x: usize = self.min.x - 1;
                    while (x < self.max.x + 1) : (x += 1) {
                        const pos = Pos.init(x, y, z, w);

                        if (self.cells[self.next].contains(pos)) {
                            _ = self.cells[self.next].remove(pos);
                        }

                        var old = Tile.Inactive;
                        if (self.cells[self.curr].contains(pos)) {
                            old = self.cells[self.curr].get(pos).?;
                        }
                        const occupied = self.countAround(pos);
                        var new = old;
                        if (old == Tile.Active and (occupied < 2 or occupied > 3)) {
                            new = Tile.Inactive;
                        }
                        if (old == Tile.Inactive and (occupied == 3)) {
                            new = Tile.Active;
                        }
                        // std.debug.warn("AROUND {} = {}, {} => {}\n", .{ pos, occupied, old, new });

                        if (new == Tile.Inactive) continue;
                        _ = self.cells[self.next].put(pos, new) catch unreachable;

                        if (min.x > pos.x) min.x = pos.x;
                        if (min.y > pos.y) min.y = pos.y;
                        if (min.z > pos.z) min.z = pos.z;
                        if (min.w > pos.w) min.w = pos.w;
                        if (max.x <= pos.x) max.x = pos.x + 1;
                        if (max.y <= pos.y) max.y = pos.y + 1;
                        if (max.z <= pos.z) max.z = pos.z + 1;
                        if (max.w <= pos.w) max.w = pos.w + 1;
                    }
                }
            }
        }
        self.min = min;
        self.max = max;
        self.curr = 1 - self.curr;
        self.next = 1 - self.next;
    }

    fn countAround(self: *Map, pos: Pos) usize {
        var count: usize = 0;
        var dw: isize = -1;
        while (dw <= 1) : (dw += 1) {
            var dz: isize = -1;
            while (dz <= 1) : (dz += 1) {
                var dy: isize = -1;
                while (dy <= 1) : (dy += 1) {
                    var dx: isize = -1;
                    while (dx <= 1) : (dx += 1) {
                        if (dy == 0 and dx == 0 and dz == 0 and dw == 0) continue;

                        var sx = @intCast(isize, pos.x);
                        var sy = @intCast(isize, pos.y);
                        var sz = @intCast(isize, pos.z);
                        var sw = @intCast(isize, pos.w);

                        sx += dx;
                        sy += dy;
                        sz += dz;
                        sw += dw;
                        const nx = @intCast(usize, sx);
                        const ny = @intCast(usize, sy);
                        const nz = @intCast(usize, sz);
                        const nw = @intCast(usize, sw);
                        const np = Pos.init(nx, ny, nz, nw);

                        if (!self.cells[self.curr].contains(np)) continue;
                        const tile = self.cells[self.curr].get(np).?;
                        if (tile != Tile.Active) continue;
                        count += 1;
                    }
                }
            }
        }
        return count;
    }
};

test "sample part a" {
    const data: []const u8 =
        \\.#.
        \\..#
        \\###
    ;

    var map = Map.init(Map.Space.Dim3);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        map.add_line(line);
    }

    // Before any cycles:
    //
    // z=0
    // .#.
    // ..#
    // ###
    //
    //
    // After 1 cycle:
    //
    // z=-1
    // #..
    // ..#
    // .#.
    //
    // z=0
    // #.#
    // .##
    // .#.
    //
    // z=1
    // #..
    // ..#
    // .#.
    //
    //
    // After 2 cycles:
    //
    // z=-2
    // .....
    // .....
    // ..#..
    // .....
    // .....
    //
    // z=-1
    // ..#..
    // .#..#
    // ....#
    // .#...
    // .....
    //
    // z=0
    // ##...
    // ##...
    // #....
    // ....#
    // .###.
    //
    // z=1
    // ..#..
    // .#..#
    // ....#
    // .#...
    // .....
    //
    // z=2
    // .....
    // .....
    // ..#..
    // .....
    // .....
    //
    //
    // After 3 cycles:
    //
    // z=-2
    // .......
    // .......
    // ..##...
    // ..###..
    // .......
    // .......
    // .......
    //
    // z=-1
    // ..#....
    // ...#...
    // #......
    // .....##
    // .#...#.
    // ..#.#..
    // ...#...
    //
    // z=0
    // ...#...
    // .......
    // #......
    // .......
    // .....##
    // .##.#..
    // ...#...
    //
    // z=1
    // ..#....
    // ...#...
    // #......
    // .....##
    // .#...#.
    // ..#.#..
    // ...#...
    //
    // z=2
    // .......
    // .......
    // ..##...
    // ..###..
    // .......
    // .......
    // .......

    // map.show();

    // map.step();
    // map.show();

    // map.step();
    // map.show();

    // map.step();
    // map.show();

    // map.step();
    // map.show();

    // map.step();
    // map.show();

    // map.step();
    // map.show();

    const count = map.run(6);
    try testing.expect(count == 112);
}

test "sample part b" {
    const data: []const u8 =
        \\.#.
        \\..#
        \\###
    ;

    var map = Map.init(Map.Space.Dim4);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        map.add_line(line);
    }

    // Before any cycles:
    //
    // z=0, w=0
    // .#.
    // ..#
    // ###
    //
    //
    // After 1 cycle:
    //
    // z=-1, w=-1
    // #..
    // ..#
    // .#.
    //
    // z=0, w=-1
    // #..
    // ..#
    // .#.
    //
    // z=1, w=-1
    // #..
    // ..#
    // .#.
    //
    // z=-1, w=0
    // #..
    // ..#
    // .#.
    //
    // z=0, w=0
    // #.#
    // .##
    // .#.
    //
    // z=1, w=0
    // #..
    // ..#
    // .#.
    //
    // z=-1, w=1
    // #..
    // ..#
    // .#.
    //
    // z=0, w=1
    // #..
    // ..#
    // .#.
    //
    // z=1, w=1
    // #..
    // ..#
    // .#.
    //
    //
    // After 2 cycles:
    //
    // z=-2, w=-2
    // .....
    // .....
    // ..#..
    // .....
    // .....
    //
    // z=-1, w=-2
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=0, w=-2
    // ###..
    // ##.##
    // #...#
    // .#..#
    // .###.
    //
    // z=1, w=-2
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=2, w=-2
    // .....
    // .....
    // ..#..
    // .....
    // .....
    //
    // z=-2, w=-1
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=-1, w=-1
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=0, w=-1
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=1, w=-1
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=2, w=-1
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=-2, w=0
    // ###..
    // ##.##
    // #...#
    // .#..#
    // .###.
    //
    // z=-1, w=0
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=0, w=0
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=1, w=0
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=2, w=0
    // ###..
    // ##.##
    // #...#
    // .#..#
    // .###.
    //
    // z=-2, w=1
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=-1, w=1
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=0, w=1
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=1, w=1
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=2, w=1
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=-2, w=2
    // .....
    // .....
    // ..#..
    // .....
    // .....
    //
    // z=-1, w=2
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=0, w=2
    // ###..
    // ##.##
    // #...#
    // .#..#
    // .###.
    //
    // z=1, w=2
    // .....
    // .....
    // .....
    // .....
    // .....
    //
    // z=2, w=2
    // .....
    // .....
    // ..#..
    // .....
    // .....

    // map.show();

    // map.step();
    // map.show();

    // map.step();
    // map.show();

    // map.step();
    // map.show();

    // map.step();
    // map.show();

    // map.step();
    // map.show();

    // map.step();
    // map.show();

    const count = map.run(6);
    try testing.expect(count == 848);
}
