const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Race = @import("./module.zig").Race;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var race = Race.init(allocator);
    defer race.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try race.addLine(line);
    }
    // race.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try race.getWinnerDistanceAfter(2503);
            const expected = @as(usize, 2655);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try race.getWinnerPointsAfter(2503);
            const expected = @as(usize, 1059);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
