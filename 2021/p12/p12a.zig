const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() anyerror!void {
    var map = Map.init(false);
    defer map.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try map.process_line(line);
    }

    const total_paths = map.count_total_paths();
    const out = std.io.getStdOut().writer();
    try out.print("Total paths: {}\n", .{total_paths});
}
