const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Depot = @import("./module.zig").Depot;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var depot = Depot.init();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try depot.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = depot.getPasswordCount(false);
            const expected = @as(usize, 910);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = depot.getPasswordCount(true);
            const expected = @as(usize, 598);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
