const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Message = @import("./module.zig").Message;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var message = Message.init(part == .part2);

    const inp = std.io.getStdIn().reader();
    var buf: [1024 * 20]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try message.addLine(line);
        // message.show();
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try message.getExpandedLength();
            const expected = @as(usize, 74532);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try message.getExpandedLength();
            const expected = @as(usize, 11558231665);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
