const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Scrambler = @import("./module.zig").Scrambler;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var scrambler = Scrambler.init(allocator);
    defer scrambler.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try scrambler.addLine(line);
    }
    // scrambler.show();

    var answer: []const u8 = undefined;
    switch (part) {
        .part1 => {
            answer = try scrambler.getScrambledPassword("abcdefgh");
            const expected = "agcebfdh";
            try testing.expectEqualSlices(u8, expected, answer);
        },
        .part2 => {
            answer = try scrambler.getUnscrambledPassword("fbgdceah");
            const expected = "afhdbegc";
            try testing.expectEqualSlices(u8, expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {s}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
