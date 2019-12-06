const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var map = Map.init();
    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        map.add_orbit(line);
        count += 1;
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    const hops = map.count_hops("YOU", "SAN");
    try out.print("Read {} lines, hops: {}\n", count, hops);
}
