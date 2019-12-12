const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var map = Map.init();
    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;
        map.add_line(line);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    var j: usize = 0;
    while (j < 1000000) : (j += 1) {
        map.step();
    }
    map.show();
    std.debug.warn("Cycle size: {}\n", map.cycle_size());
}
