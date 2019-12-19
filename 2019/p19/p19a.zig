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

        var map = Map.init(0, 50, 100, 100, line);
        defer map.deinit();

        const output = map.run_to_get_map();
        map.show();
        try out.print("Pulled {} positions\n", output);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines\n", count);
}
