const std = @import("std");
const allocator = std.heap.page_allocator;
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

        var route = std.ArrayList(u8).init(allocator);
        defer route.deinit();

        map.computer.parse(line);
        map.computer.hack(0, 2);
        map.run_to_get_map();
        // map.show();
        const result = map.walk(&route);
        try out.print("Sum of alignments: {}\n", .{result});
        // Sum of alignments: 6672
    }
    try out.print("Read {} lines\n", .{count});
}
