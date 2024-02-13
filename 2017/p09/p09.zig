const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Stream = @import("./module.zig").Stream;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var stream = Stream.init();
    defer stream.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [20 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try stream.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = try stream.getTotalScore();
            const expected = @as(usize, 9251);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try stream.getNonCanceledCharacters();
            const expected = @as(usize, 4322);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
