const std = @import("std");

pub const Board = struct {
    map: std.AutoHashMap(i32, void),
    cx: u8,
    cy: u8,

    pub fn init() Board {
        var self = Board{
            .map = std.AutoHashMap(i32, void).init(std.heap.direct_allocator),
            .cx = 0,
            .cy = 0,
        };
        defer self.map.deinit();
        return self;
    }

    pub fn trace(self: *Board, str: []u8, first: bool) void {
        var it = std.mem.separate(str, ",");
        var md: i32 = 999999999;
        var mx: i32 = 0;
        var my: i32 = 0;
        var cx: i32 = 0;
        var cy: i32 = 0;
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
            // std.debug.warn("{} {} {} {}\n", dir, len, dx, dy);
            var j: usize = 0;
            while (j < len) : (j += 1) {
                cx += dx;
                cy += dy;
                const pos: i32 = @intCast(i32, @intCast(i32, cx) * @intCast(i32, 10000)) + @intCast(i32, cy);
                if (first) {
                    // std.debug.warn("{} SET {} {} {}\n", count, cx, cy, pos);
                    _ = try map.put(pos, {});
                } else if (map.contains(pos)) {
                    // std.debug.warn("{} HIT {} {}\n", count, cx, cy);
                    const ax = try std.math.absInt(cx);
                    const ay = try std.math.absInt(cy);
                    const d = ax + ay;
                    if (md > d) {
                        md = d;
                        mx = cx;
                        my = cy;
                    }
                }
            }
        }
    }

    pub fn get(self: Board, x: i32, y: i32) u8 {
        return 0;
    }

    pub fn set(self: *Board, x: i32, y: i32) u8 {
        // const max = 6000 / 2;
        // const min = -max;
        // if (x <= min or x >= max) {
        //     std.debug.warn("X {}\n", x);
        //     @panic("BOOM X");
        // }
        // if (y <= min or y >= max) {
        //     std.debug.warn("Y {}\n", y);
        //     @panic("BOOM Y");
        // }
        // const ux: usize = @intCast(usize, x);
        // const uy: usize = @intCast(usize, y);
        // self.mem[ux][uy] += 1;
        // std.debug.warn("SET {} {}\n", ux, uy);
        return 0;
    }
};
