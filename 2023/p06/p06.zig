const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Competition = @import("./island.zig").Competition;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var competition = Competition.init(allocator, part == .part2);
    defer competition.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try competition.addLine(line);
    }
    // competition.show();

    var answer: u64 = 0;
    switch (part) {
        .part1 => {
            answer = competition.getProductWinningWays();
            const expected = @as(usize, 1108800);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = competition.getProductWinningWays();
            const expected = @as(usize, 36919753);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
