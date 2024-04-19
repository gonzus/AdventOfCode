const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Chocolate = @import("./module.zig").Chocolate;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var chocolate = try Chocolate.init(allocator);
    defer chocolate.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try chocolate.addLine(line);
    }
    // chocolate.show();

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    switch (part) {
        .part1 => {
            const answer = try chocolate.findScoreForLast(10);
            const expected = "2145581131";
            try testing.expectEqualStrings(expected, answer);
            try out.print("Answer: {s}\n", .{answer});
        },
        .part2 => {
            const answer = try chocolate.countRecipesWithEndingNumber();
            const expected = @as(usize, 20283721);
            try testing.expectEqual(expected, answer);
            try out.print("Answer: {}\n", .{answer});
        },
    }

    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
