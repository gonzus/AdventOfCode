const std = @import("std");
const Image = @import("./img.zig").Image;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        var image = Image.init(std.heap.direct_allocator, 25, 6);
        image.parse(line);
        const result = image.find_layer_with_fewest_zeros();
        try out.print("Image {}, result is {}\n", count, result);
        count += 1;
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines\n", count);
}
