const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var map = Map.init();
    defer map.deinit();

    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;
        map.parse(line);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    map.find_portals();
    map.find_graph();
    var it = map.portals.iterator();
    // map.show();
    const result = map.find_path_to_target(false);
    try out.print("Path length is {}\n", result);
}
