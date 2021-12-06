const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() !void {
    var map = Map.init();
    defer map.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [20480]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        map.parse(line);
    }
    // map.show();
    map.walk_map();
    const dist = map.walk_graph();
    std.debug.warn("DIST {}\n", .{dist});
}
