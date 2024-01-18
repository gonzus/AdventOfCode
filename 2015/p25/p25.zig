const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Manual = @import("./module.zig").Manual;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var manual = Manual.initDefault();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try manual.addLine(line);
    }
    // manual.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = manual.getCode();
            const expected = @as(usize, 9132360);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = 42;
            const expected = @as(usize, answer);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
