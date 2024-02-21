const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Duel = @import("./module.zig").Duel;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var duel = Duel.init(part == .part2);

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try duel.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = try duel.countMatchesUpTo(40_000_000);
            const expected = @as(usize, 594);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try duel.countMatchesUpTo(5_000_000);
            const expected = @as(usize, 328);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
