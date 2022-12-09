const std = @import("std");
const command = @import("./util/command.zig");
const Map = @import("./map.zig").Map;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var map = try Map.init(allocator, if (part == 1) 1 else 9);
    defer map.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try map.add_line(line);
    }

    const count = map.count_tail_visits();
    const out = std.io.getStdOut().writer();
    try out.print("Tail visits: {}\n", .{count});
    return 0;
}
