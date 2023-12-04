const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Game = @import("./island.zig").Game;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var game = Game.init(allocator);
    defer game.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try game.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = game.getSumPoints();
            const expected = @as(usize, 26426);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = game.getTotalCards();
            const expected = @as(usize, 6227972);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
