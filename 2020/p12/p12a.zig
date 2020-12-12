const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() anyerror!void {
    var map = Map.init(Map.Navigation.Direction);
    defer map.deinit();

    const inp = std.io.bufferedInStream(std.io.getStdIn().inStream()).inStream();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        map.run_action(line);
    }

    const distance = map.manhattan_distance();

    const out = std.io.getStdOut().outStream();
    try out.print("Distance: {}\n", .{distance});
}
