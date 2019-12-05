const std = @import("std");

pub const Board = struct {
    dist: Distance,
    map: std.AutoHashMap(i32, u32),
    md: u32,
    mx: i32,
    my: i32,

    pub const Distance = enum {
        Manhattan,
        Travelled,
    };

    pub fn init(dist: Board.Distance) Board {
        var self = Board{
            .dist = dist,
            .map = std.AutoHashMap(i32, u32).init(std.heap.direct_allocator),
            .md = std.math.maxInt(u32),
            .mx = 0,
            .my = 0,
        };
        return self;
    }

    pub fn destroy(self: Board) void {
        self.map.deinit();
    }

    pub fn trace(self: *Board, str: []const u8, first: bool) void {
        var it = std.mem.separate(str, ",");
        var cx: i32 = 0;
        var cy: i32 = 0;
        var cl: u32 = 0;
        while (it.next()) |what| {
            const dir = what[0];
            const len = std.fmt.parseInt(usize, what[1..], 10) catch 0;
            var dx: i32 = 0;
            dx = switch (dir) {
                'R' => 1,
                'L' => -1,
                else => 0,
            };
            var dy: i32 = 0;
            dy = switch (dir) {
                'U' => 1,
                'D' => -1,
                else => 0,
            };
            var j: usize = 0;
            while (j < len) : (j += 1) {
                cx += dx;
                cy += dy;
                cl += 1;
                const pos = cx * 10000 + cy;
                if (first) {
                    _ = self.map.put(pos, cl) catch unreachable;
                } else if (self.map.contains(pos)) {
                    const val = self.map.get(pos).?.value;
                    const d = switch (self.dist) {
                        Distance.Manhattan => manhattan(cx, cy),
                        Distance.Travelled => travelled(val, cl),
                    };
                    if (self.md > d) {
                        self.md = d;
                        self.mx = cx;
                        self.my = cy;
                    }
                }
            }
        }
    }
};

fn manhattan(x: i32, y: i32) u32 {
    const ax = std.math.absInt(x) catch 0;
    const ay = std.math.absInt(y) catch 0;
    return @intCast(u32, ax) + @intCast(u32, ay);
}

fn travelled(v0: u32, v1: u32) u32 {
    return v0 + v1;
}
