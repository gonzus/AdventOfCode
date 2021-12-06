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
        const result = image.find_layer_with_fewest_blacks();
        try out.print("Image {}, result is {}\n", .{ count, result });
        count += 1;
    }
    try out.print("Read {} lines\n", .{count});
}
