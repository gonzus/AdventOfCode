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
        _ = map.walk(&route);
        // _ = map.split_route(route.toOwnedSlice());
        const result = map.program_and_run();
        try out.print("Computer reported dust as {}\n", .{result});
        // Computer reported dust as 923017
    }
    try out.print("Read {} lines\n", .{count});
}
