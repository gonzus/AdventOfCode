const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Street = @import("./module.zig").Street;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var street = Street.init(part == .part2);

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try street.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = street.findLowestHouseWithPresents();
            const expected = @as(usize, 831600);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = street.findLowestHouseWithPresents();
            const expected = @as(usize, 884520);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
