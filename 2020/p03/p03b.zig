const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() anyerror!void {
    var map = Map.init();
    defer map.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        map.add_line(line);
    }
    // map.show();

    const specs = [_][2]usize{
        [_]usize{ 1, 1 },
        [_]usize{ 3, 1 },
        [_]usize{ 5, 1 },
        [_]usize{ 7, 1 },
        [_]usize{ 1, 2 },
    };
    const product = map.traverse_several(specs[0..]);

    const out = std.io.getStdOut().writer();
    try out.print("Product: {}\n", .{product});
}
