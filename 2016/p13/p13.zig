const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Maze = @import("./module.zig").Maze;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var maze = Maze.init(allocator);
    defer maze.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try maze.addLine(line);
    }
    // maze.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try maze.countStepsToVisit(31, 39);
            const expected = @as(usize, 92);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try maze.countLocationsForSteps(50);
            const expected = @as(usize, 124);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
