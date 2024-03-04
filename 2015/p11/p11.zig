const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Password = @import("./module.zig").Password;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var password = Password.init();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try password.addLine(line);
    }

    var answer: []const u8 = undefined;
    switch (part) {
        .part1 => {
            answer = try password.findNext();
            const expected = "hepxxyzz";
            try testing.expectEqualStrings(expected, answer);
        },
        .part2 => {
            answer = try password.findNext();
            answer = try password.findNext();
            const expected = "heqaabcc";
            try testing.expectEqualStrings(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {s}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
