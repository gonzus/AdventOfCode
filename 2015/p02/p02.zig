const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Paper = @import("./module.zig").Paper;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var paper = Paper.init();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try paper.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = paper.getTotalPaperNeeded();
            const expected = @as(usize, 1598415);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = paper.getTotalRibbonNeeded();
            const expected = @as(usize, 3812909);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
