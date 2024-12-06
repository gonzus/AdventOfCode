const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Map = @import("./map.zig").Map;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var map = Map.init();
    defer map.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try map.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try map.countVisited();
            const expected = @as(usize, 5305);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try map.countPossibleObstructions();
            const expected = @as(usize, 2143);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
