const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Party = @import("./module.zig").Party;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var party = Party.init();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try party.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = party.getWinningElfNext();
            const expected = @as(usize, 1808357);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = party.getWinningElfAcross();
            const expected = @as(usize, 1407007);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
