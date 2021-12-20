const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() anyerror!void {
    var map = Map.init(Map.Mode.RUN);
    defer map.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try map.process_line(line);
    }

    try map.process(50);

    const count = map.count_pixels_on();
    const out = std.io.getStdOut().writer();
    try out.print("Pixels on: {}\n", .{count});
}
