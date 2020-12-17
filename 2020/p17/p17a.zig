const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() anyerror!void {
    var map = Map.init(Map.Space.Dim3);
    defer map.deinit();

    const inp = std.io.bufferedInStream(std.io.getStdIn().inStream()).inStream();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        map.add_line(line);
    }
    // map.show();

    const count = map.run(6);

    const out = std.io.getStdOut().outStream();
    try out.print("Active: {}\n", .{count});
}
