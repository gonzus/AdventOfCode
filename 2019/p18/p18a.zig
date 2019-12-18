const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var map = Map.init();
    defer map.deinit();
    while (std.io.readLine(&buf)) |line| {
        map.parse(line);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    // map.show();
    map.walk_map();
    const dist = map.walk_graph();
    std.debug.warn("DIST {}\n", dist);
}
