const std = @import("std");
const Timetable = @import("./timetable.zig").Timetable;

pub fn main() anyerror!void {
    var timetable = Timetable.init();
    defer timetable.deinit();

    const inp = std.io.bufferedInStream(std.io.getStdIn().inStream()).inStream();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        timetable.add_line(line);
    }

    const timestamp = timetable.earliest_departure();

    const out = std.io.getStdOut().outStream();
    try out.print("Earliest: {}\n", .{timestamp});
}
