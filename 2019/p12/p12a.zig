const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() !void {
    var map = Map.init();
    defer map.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [20480]u8 = undefined;
    var count: u32 = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;
        map.add_line(line);
    }
    var j: usize = 0;
    while (j < 1000) : (j += 1) {
        map.step();
    }

    const out = std.io.getStdOut().writer();
    try out.print("Total energy: {}\n", .{map.total_energy()});
}
