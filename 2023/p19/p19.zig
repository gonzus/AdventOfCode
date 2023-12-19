const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Engine = @import("./island.zig").Engine;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var engine = Engine.init(allocator);
    defer engine.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try engine.addLine(line);
    }
    // engine.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = engine.getRatingsForAcceptedParts();
            const expected = @as(usize, 489392);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try engine.getTotalRatings();
            const expected = @as(usize, 134370637448305);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
