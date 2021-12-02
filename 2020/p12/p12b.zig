const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() anyerror!void {
    var map = Map.init(Map.Navigation.Waypoint);
    defer map.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        map.run_action(line);
    }

    const distance = map.manhattan_distance();

    const out = std.io.getStdOut().writer();
    try out.print("Distance: {}\n", .{distance});
}
