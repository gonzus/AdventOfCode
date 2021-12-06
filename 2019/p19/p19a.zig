const std = @import("std");
const Map = @import("./map.zig").Map;

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [20480]u8 = undefined;
    var count: u32 = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;

        var map = Map.init(0, 50, 100, 100, line);
        defer map.deinit();

        const output = map.run_to_get_map();
        map.show();
        try out.print("Pulled {} positions\n", .{output});
    }
    try out.print("Read {} lines\n", .{count});
}
