const std = @import("std");
const Number = @import("./number.zig").Number;

pub fn main() anyerror!void {
    var number = Number.init();
    defer number.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try number.process_line(line);
    }

    const mag = number.add_all();
    const out = std.io.getStdOut().writer();
    try out.print("Magnitude: {}\n", .{mag});
}
