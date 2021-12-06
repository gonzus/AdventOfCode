const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() !void {
    var map = Map.init();
    defer map.deinit();

    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [20480]u8 = undefined;
    var count: u32 = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;
        map.parse(line);
    }
    map.find_portals();
    map.find_graph();
    // map.show();
    const result = map.find_path_to_target(false);
    try out.print("Path length is {}\n", .{result});
}
