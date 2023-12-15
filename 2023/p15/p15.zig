const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Sequence = @import("./island.zig").Sequence;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var sequence = Sequence.init(allocator);
    defer sequence.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [25 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try sequence.addLine(line);
        // sequence.show();
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = sequence.getSumHashes();
            const expected = @as(usize, 516469);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = sequence.getFocusingPower();
            const expected = @as(usize, 221627);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
