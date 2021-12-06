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
    const result = map.find_cycle_size();
    const out = std.io.getStdOut().writer();
    try out.print("Cycle size: {}\n", .{result});
}
