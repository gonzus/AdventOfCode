const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Cave = @import("./module.zig").Cave;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var cave = Cave.init(allocator);
    defer cave.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try cave.addLine(line);
    }
    // cave.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try cave.getRiskLevel();
            const expected = @as(usize, 7901);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try cave.findBestRoute();
            const expected = @as(usize, 1087);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
