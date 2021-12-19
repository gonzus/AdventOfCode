const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() anyerror!void {
    var map = Map.init();
    defer map.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try map.process_line(line);
    }

    const unique = try map.match_all_scanners();
    const out = std.io.getStdOut().writer();
    try out.print("Unique beacons: {}\n", .{unique});
}
