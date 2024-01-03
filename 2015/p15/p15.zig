const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Recipe = @import("./module.zig").Recipe;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var recipe = Recipe.init(allocator, if (part == .part2) 500 else 0);
    defer recipe.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try recipe.addLine(line);
    }
    // recipe.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try recipe.getBestCookieScore(100);
            const expected = @as(usize, 13882464);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try recipe.getBestCookieScore(100);
            const expected = @as(usize, 11171160);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
