const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Ship = @import("./module.zig").Ship;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var ship = Ship.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [5 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try ship.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = try ship.discoverOxygen();
            const expected = @as(usize, 258);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try ship.measureTimeToFillWithOxygen();
            const expected = @as(usize, 372);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
