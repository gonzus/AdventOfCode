const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() anyerror!void {
    var map = Map.init();
    defer map.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        map.process_line(line);
    }

    const product = map.get_largest_n_basins_product(3);
    const out = std.io.getStdOut().writer();
    try out.print("Product of largest basins: {}\n", .{product});
}
