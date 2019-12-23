const std = @import("std");
const assert = std.debug.assert;
const Computer = @import("./computer.zig").Computer;

pub const Map = struct {
    pub const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            return Pos{
                .x = x,
                .y = y,
            };
        }

        pub fn equal(self: Pos, other: Pos) bool {
            return self.x == other.x and self.y == other.y;
        }
    };

    cells: std.AutoHashMap(Pos, Tile),
    pmin: Pos,
    pmax: Pos,
    prg: []const u8,

    pub const Tile = enum(u8) {
        Stationary = 0,
        Pulled = 1,
    };

    pub fn init(minx: usize, miny: usize, maxx: usize, maxy: usize, prg: []const u8) Map {
        var self = Map{
            .cells = std.AutoHashMap(Pos, Tile).init(std.heap.direct_allocator),
            .pmin = Pos.init(minx, miny),
            .pmax = Pos.init(maxx, maxy),
            .prg = prg,
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.cells.deinit();
    }

    pub fn run_for_one_point(self: *Map, p: Pos) Tile {
        var comp = Computer.init(true);
        defer comp.deinit();

        comp.parse(self.prg);
        comp.enqueueInput(@intCast(i64, p.x));
        comp.enqueueInput(@intCast(i64, p.y));
        comp.run();
        const output = comp.getOutput();
        if (output == null) {
            std.debug.warn("FUCK\n");
            return Tile.Stationary;
        }
        const v = @intCast(u8, output.?);
        // std.debug.warn("RUN {} {} => {}\n", p.x, p.y, v);
        const t = @intToEnum(Tile, v);
        return t;
    }

    pub fn find_first_pulled(self: *Map, y: usize) usize {
        var xl: usize = 0;
        var xh: usize = (y - 48) * 45 / 41 + 53;
        var s: usize = 1;
        var t: Tile = undefined;
        while (true) {
            const p = Pos.init(xh, y);
            t = self.run_for_one_point(p);
            // std.debug.warn("D {} {} {}\n", xh, y, t);
            if (t == Tile.Pulled) break;
            xh += s;
            s *= 2;
        }
        while (xl <= xh) {
            var xm: usize = (xl + xh) / 2;
            const p = Pos.init(xm, y);
            t = self.run_for_one_point(p);
            // std.debug.warn("M {} {} {}\n", xm, y, t);
            if (t == Tile.Pulled) {
                xh = xm - 1;
            } else {
                xl = xm + 1;
            }
        }
        // if (t != Tile.Pulled) xl += 1;
        // std.debug.warn("F {} {}\n", xl, y);
        return xl;
    }

    pub fn run_to_get_map(self: *Map) usize {
        var count: usize = 0;
        var y: usize = self.pmin.y;
        main: while (y < self.pmax.y) : (y += 1) {
            var x: usize = self.pmin.x;
            while (x < self.pmax.x) : (x += 1) {
                // if (self.computer.halted) break :main;
                const p = Pos.init(x, y);
                const t = self.run_for_one_point(p);
                self.set_pos(p, t);
                if (t == Tile.Pulled) count += 1;
            }
        }
        return count;
    }

    pub fn set_pos(self: *Map, pos: Pos, mark: Tile) void {
        _ = self.cells.put(pos, mark) catch unreachable;
    }

    pub fn show(self: Map) void {
        std.debug.warn("MAP: {} {} - {} {}\n", self.pmin.x, self.pmin.y, self.pmax.x, self.pmax.y);
        var y: usize = self.pmin.y;
        while (y < self.pmax.y) : (y += 1) {
            std.debug.warn("{:4} | ", y);
            var x: usize = self.pmin.x;
            while (x < self.pmax.x) : (x += 1) {
                const p = Pos.init(x, y);
                const g = self.cells.get(p);
                var c: u8 = ' ';
                if (g != null) {
                    const v = g.?.value;
                    switch (v) {
                        Tile.Stationary => c = '.',
                        Tile.Pulled => c = '#',
                    }
                }
                std.debug.warn("{c}", c);
            }
            std.debug.warn("\n");
        }
    }
};
