const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Knot = @import("./module.zig").Knot;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var knot = Knot.init(allocator, 0, part == .part2);
    defer knot.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try knot.addLine(line);
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    switch (part) {
        .part1 => {
            const answer = try knot.getProductFirstTwo();
            const expected = @as(usize, 13760);
            try testing.expectEqual(expected, answer);
            try out.print("Answer: {}\n", .{answer});
        },
        .part2 => {
            const answer = try knot.getFinalHash();
            const expected = "2da93395f1a6bb3472203252e3b17fe5";
            try testing.expectEqualSlices(u8, expected, answer);
            try out.print("Answer: {s}\n", .{answer});
        },
    }

    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
