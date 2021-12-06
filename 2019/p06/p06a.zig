const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() !void {
    var map = Map.init();
    defer map.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    var count: u32 = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        map.add_orbit(line);
        count += 1;
    }
    const orbits = map.count_orbits();

    const out = std.io.getStdOut().writer();
    try out.print("Read {} lines, orbits: {}\n", .{ count, orbits });
}
