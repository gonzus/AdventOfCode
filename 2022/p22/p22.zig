const std = @import("std");
const testing = std.testing;
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

    var map = Map.init(allocator);
    defer map.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try map.add_line(line);
    }
    // map.show();

    var password: usize = 0;
    if (part == 1) {
        password = try map.walk(0);
        const expected = @as(usize, 181128);
        try testing.expectEqual(expected, password);
    } else {
        password = try map.walk(50);
        const expected = @as(usize, 52311);
        try testing.expectEqual(expected, password);
    }

    const out = std.io.getStdOut().writer();
    try out.print("Password: {}\n", .{password});

    return 0;
}
