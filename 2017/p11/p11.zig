const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Grid = @import("./module.zig").Grid;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var grid = Grid.init();

    const inp = std.io.getStdIn().reader();
    var buf: [30 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try grid.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = grid.getDistanceFromOrigin();
            const expected = @as(usize, 773);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = grid.getFarthestDistance();
            const expected = @as(usize, 1560);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
