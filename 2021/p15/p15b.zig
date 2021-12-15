const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() anyerror!void {
    var map = Map.init(Map.Mode.Large, Map.Algo.Dijkstra);
    defer map.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try map.process_line(line);
    }

    const risk = try map.get_total_risk();
    const out = std.io.getStdOut().writer();
    try out.print("Total risk: {}\n", .{risk});
}
