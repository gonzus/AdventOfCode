const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Computer = @import("./computer.zig").Computer;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var computer = Computer.init(part == .part2);
    defer computer.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try computer.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try computer.runMultiplies();
            const expected = @as(usize, 182780583);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try computer.runMultiplies();
            const expected = @as(usize, 90772405);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
