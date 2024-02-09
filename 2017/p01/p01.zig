const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Captcha = @import("./module.zig").Captcha;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var captcha = Captcha.init(part == .part2);

    const inp = std.io.getStdIn().reader();
    var buf: [10 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try captcha.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = captcha.getSolution();
            const expected = @as(usize, 1119);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = captcha.getSolution();
            const expected = @as(usize, 1420);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
