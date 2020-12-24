const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() anyerror!void {
    var map = Map.init();
    defer map.deinit();

    const inp = std.io.bufferedInStream(std.io.getStdIn().inStream()).inStream();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        map.process_tile(line);
    }

    const black = map.count_black();

    const out = std.io.getStdOut().outStream();
    try out.print("Black tiles: {}\n", .{black});
}
