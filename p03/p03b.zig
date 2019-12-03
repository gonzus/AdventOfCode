const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var count: u32 = 0;
    var map = std.AutoHashMap(i32, i32).init(std.heap.direct_allocator);
    defer map.deinit();

    while (std.io.readLine(&buf)) |line| {
        count += 1;
        var it = std.mem.separate(line, ",");
        var md: i32 = 999999999;
        var mx: i32 = 0;
        var my: i32 = 0;
        var cx: i32 = 0;
        var cy: i32 = 0;
        var cl: i32 = 0;
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
                cl += 1;
                const pos: i32 = @intCast(i32, @intCast(i32, cx) * @intCast(i32, 10000)) + @intCast(i32, cy);
                if (count == 1) {
                    // std.debug.warn("{} SET {} {} {}\n", count, cx, cy, pos);
                    _ = try map.put(pos, cl);
                } else if (map.contains(pos)) {
                    // std.debug.warn("{} HIT {} {}\n", count, cx, cy);
                    const d0 = map.get(pos).?.value;
                    const d1 = cl;
                    const d = d0 + d1;
                    if (md > d) {
                        md = d;
                        mx = cx;
                        my = cy;
                    }
                }
            }
        }
        std.debug.warn("MIN {} {} {}\n", md, mx, my);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines\n", count);
}
