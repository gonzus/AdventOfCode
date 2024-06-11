const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Scaffold = @import("./module.zig").Scaffold;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var scaffold = Scaffold.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [5 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try scaffold.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = try scaffold.getSumOfAlignmentParameters();
            const expected = @as(usize, 6052);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try scaffold.getTotalDustCollected();
            const expected = @as(usize, 752491);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
