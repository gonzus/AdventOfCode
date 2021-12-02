const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() anyerror!void {
    var map = Map.init();
    defer map.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        map.add_line(line);
    }
    // map.show();

    const count = map.traverse(3, 1);

    const out = std.io.getStdOut().writer();
    try out.print("Trees: {}\n", .{count});
}
