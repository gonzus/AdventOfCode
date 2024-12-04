const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Game = @import("./game.zig").Game;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var game = Game.init();
    defer game.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try game.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try game.countXMAS();
            const expected = @as(usize, 2530);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try game.countMAS();
            const expected = @as(usize, 1921);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
