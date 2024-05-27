const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Sleigh = @import("./module.zig").Sleigh;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var sleigh = Sleigh.init(allocator, 60);

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try sleigh.addLine(line);
    }
    // sleigh.show();

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    switch (part) {
        .part1 => {
            const answer = try sleigh.sortSteps();
            const expected = "BFLNGIRUSJXEHKQPVTYOCZDWMA";
            try testing.expectEqualStrings(expected, answer);
            try out.print("Answer: {s}\n", .{answer});
        },
        .part2 => {
            const answer = try sleigh.runSteps(5);
            const expected = @as(usize, 880);
            try testing.expectEqual(expected, answer);
            try out.print("Answer: {}\n", .{answer});
        },
    }

    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
