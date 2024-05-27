const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Polymer = @import("./module.zig").Polymer;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var polymer = Polymer.init();

    const inp = std.io.getStdIn().reader();
    var buf: [55 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try polymer.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = try polymer.fullyReact();
            const expected = @as(usize, 9116);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try polymer.findLargestBlocker();
            const expected = @as(usize, 6890);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
