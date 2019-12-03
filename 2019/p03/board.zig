const std = @import("std");

pub const Board = struct {
    map: std.AutoHashMap(i32, u32),
    md: u32,
    mx: i32,
    my: i32,

    pub fn init() Board {
        var self = Board{
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

    pub fn trace(self: *Board, str: []u8, first: bool, dist: fn (x: i32, y: i32, v0: u32, v1: u32) u32) !void {
        var it = std.mem.separate(str, ",");
        var cx: i32 = 0;
        var cy: i32 = 0;
        var cl: u32 = 0;
        while (it.next()) |what| {
            const dir = what[0];
            const len = try std.fmt.parseInt(usize, what[1..], 10);
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
                    _ = try self.map.put(pos, cl);
                } else if (self.map.contains(pos)) {
                    const val = self.map.get(pos).?.value;
                    const d = dist(cx, cy, val, cl);
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
