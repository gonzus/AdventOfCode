const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;

        var map = Map.init();
        defer map.deinit();

        var route = std.Buffer.initSize(allocator, 0) catch unreachable;
        defer route.deinit();

        map.computer.parse(line);
        map.computer.hack(0, 2);
        map.run_to_get_map();
        // map.show();
        const result = map.walk(&route);
        try out.print("Sum of alignments: {}\n", result);
        // Sum of alignments: 6672
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines\n", count);
}
