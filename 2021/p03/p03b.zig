const std = @import("std");
const Report = @import("./report.zig").Report;

pub fn main() anyerror!void {
    var report = Report.init();
    defer report.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        report.process_line(line);
    }

    const lsr = report.get_life_support_rating();
    const out = std.io.getStdOut().writer();
    try out.print("Life support rating: {}\n", .{lsr});
}
