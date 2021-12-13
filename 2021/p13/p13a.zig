const std = @import("std");
const Page = @import("./page.zig").Page;

pub fn main() anyerror!void {
    var page = Page.init();
    defer page.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try page.process_line(line);
    }

    const total_dots = page.dots_after_first_fold();
    const out = std.io.getStdOut().writer();
    try out.print("Total dots after first fold: {}\n", .{total_dots});
}
