const std = @import("std");
const Page = @import("./page.zig").Page;
const allocator = std.testing.allocator;

pub fn main() anyerror!void {
    var page = Page.init();
    defer page.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try page.process_line(line);
    }

    var buffer = Page.Buffer.init(allocator);
    defer buffer.deinit();
    try page.render_code(&buffer, " ", "\u{2588}");
    const out = std.io.getStdOut().writer();
    try out.print("Code:\n{s}", .{buffer.items});
}
