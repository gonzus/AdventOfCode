const std = @import("std");
const Radar = @import("./radar.zig").Radar;

pub fn main() anyerror!void {
    const window_size = 3;
    var radar = Radar.init(window_size);
    defer radar.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        radar.add_line(line);
    }

    const count = radar.get_increases();
    const out = std.io.getStdOut().writer();
    try out.print("Increases with window size {}: {}\n", .{ window_size, count });
}
