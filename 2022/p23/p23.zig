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

    const out = std.io.getStdOut().writer();
    if (part == 1) {
        const rounds = 10;
        const empty = try map.run_rounds(rounds);
        const expected = @as(usize, 4052);
        try testing.expectEqual(expected, empty);
        try out.print("Empty tiles after {} rounds: {}\n", .{rounds, empty});
    } else {
        const stable = try map.run_until_stable();
        const expected = @as(usize, 978);
        try testing.expectEqual(expected, stable);
        try out.print("Map is stable after: {}\n", .{stable});
    }

    return 0;
}
