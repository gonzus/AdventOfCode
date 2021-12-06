const std = @import("std");
const Image = @import("./img.zig").Image;

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [20480]u8 = undefined;
    var count: u32 = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var image = Image.init(std.testing.allocator, 25, 6);
        image.parse(line);
        try image.render();
        count += 1;
    }
    try out.print("Read {} lines\n", .{count});
}
