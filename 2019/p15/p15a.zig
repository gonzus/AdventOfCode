const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [20480]u8 = undefined;
    var count: u32 = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;

        var map = Map.init();
        defer map.deinit();

        map.parse_program(line);
        map.walk_around();
        // map.show();
        const dist = map.find_path_to_target();
        try out.print("Shortest distance from droid to oxygen system is {}\n", .{dist});
    }
    try out.print("Read {} lines\n", .{count});
}
