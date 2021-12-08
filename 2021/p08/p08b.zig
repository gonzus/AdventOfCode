const std = @import("std");
const Display = @import("./display.zig").Display;

pub fn main() anyerror!void {
    var display = Display.init();
    defer display.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        display.process_line(line);
    }

    const total_sum = display.get_total_sum();
    const out = std.io.getStdOut().writer();
    try out.print("Total sum: {}\n", .{total_sum});
}
