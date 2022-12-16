const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Cave = @import("./cave.zig").Cave;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var cave = Cave.init(allocator);
    defer cave.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try cave.add_line(line);
    }
    // cave.show();

    var best: usize = 0;
    if (part == 1) {
        best = try cave.find_best(30, 1);
        const expected = @as(usize, 1862);
        try testing.expectEqual(expected, best);
    } else {
        best = try cave.find_best(26, 2);
        const expected = @as(usize, 2422);
        try testing.expectEqual(expected, best);
    }
    const out = std.io.getStdOut().writer();
    try out.print("Best flow: {}\n", .{best});
    return 0;
}
