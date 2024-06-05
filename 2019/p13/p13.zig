const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Arcade = @import("./module.zig").Arcade;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var arcade = Arcade.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [10 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try arcade.addLine(line);
    }
    // arcade.show();

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = try arcade.runAndCountBlockTiles();
            const expected = @as(usize, 268);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try arcade.runWithHackedCodeAndReturnScore(2);
            const expected = @as(usize, 13989);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
