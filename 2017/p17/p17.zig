const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Spinlock = @import("./module.zig").Spinlock;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var spinlock = Spinlock.init();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try spinlock.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = try spinlock.getNumberAfterLast(2017);
            const expected = @as(usize, 136);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try spinlock.getNumberAfterZero(50_000_000);
            const expected = @as(usize, 1080289);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
