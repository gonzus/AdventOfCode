const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() anyerror!void {
    const dragon: []const u8 =
        \\..................#.
        \\#....##....##....###
        \\.#..#..#..#..#..#...
    ;

    var image = Map.Tile.init();
    defer image.deinit();
    image.set(dragon);
    // image.show();

    var map = Map.init();
    defer map.deinit();

    const inp = std.io.bufferedInStream(std.io.getStdIn().inStream()).inStream();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        map.add_line(line);
    }
    // map.show();

    map.find_layout();
    const roughness = map.find_image_in_grid(&image);

    const out = std.io.getStdOut().outStream();
    try out.print("Roughness: {}\n", .{roughness});
}
