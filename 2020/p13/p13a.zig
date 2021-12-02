const std = @import("std");
const Timetable = @import("./timetable.zig").Timetable;

pub fn main() anyerror!void {
    var timetable = Timetable.init();
    defer timetable.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        timetable.add_line(line);
    }

    const product = timetable.product_for_earliest_bus();

    const out = std.io.getStdOut().writer();
    try out.print("Product: {}\n", .{product});
}
