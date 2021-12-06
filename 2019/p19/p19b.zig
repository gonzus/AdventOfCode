const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [20480]u8 = undefined;
    var count: u32 = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;

        var map = Map.init(0, 50, 100, 100, line);
        defer map.deinit();

        var p: Map.Pos = undefined;
        var t: Map.Tile = undefined;

        var yl: usize = 100;
        var xl = map.find_first_pulled(yl);
        p = Map.Pos.init(xl + 99, yl - 99);
        t = map.run_for_one_point(p);
        std.debug.warn("L: {} {} -- opposite {} {} {}\n", .{ xl, yl, p.x, p.y, t });
        var yh: usize = 1500;
        var xh = map.find_first_pulled(yh);
        p = Map.Pos.init(xh + 99, yh - 99);
        t = map.run_for_one_point(p);
        std.debug.warn("H: {} {} -- opposite {} {} {}\n", .{ xh, yh, p.x, p.y, t });
        while (yl <= yh) {
            var ym: usize = (yl + yh) / 2;
            var xm = map.find_first_pulled(ym);
            p = Map.Pos.init(xm + 99, ym - 99);
            t = map.run_for_one_point(p);
            std.debug.warn("M: {} {} -- opposite {} {} {}\n", .{ xm, ym, p.x, p.y, t });
            if (t == Map.Tile.Pulled) {
                yh = ym - 1;
            } else {
                yl = ym + 1;
            }
        }
        // if (t != Map.Tile.Pulled) yl += 1;
        xl = map.find_first_pulled(yl);
        p = Map.Pos.init(xl, yl);
        t = map.run_for_one_point(p);
        std.debug.warn("BL: {} {} {}\n", .{ p.x, p.y, t });
        p = Map.Pos.init(xl + 99, yl - 99);
        t = map.run_for_one_point(p);
        std.debug.warn("TR: {} {} {}\n", .{ p.x, p.y, t });
        p = Map.Pos.init(xl + 99, yl);
        t = map.run_for_one_point(p);
        std.debug.warn("BR: {} {} {}\n", .{ p.x, p.y, t });
        p = Map.Pos.init(xl, yl - 99);
        t = map.run_for_one_point(p);
        std.debug.warn("TL: {} {} {}\n", .{ p.x, p.y, t });
        p = Map.Pos.init(xl, yl - 99);
        std.debug.warn("TL encoded: {}\n", .{p.x * 10000 + p.y});
    }
    try out.print("Read {} lines\n", .{count});
}
