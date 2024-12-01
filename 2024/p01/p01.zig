const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Itinerary = @import("./itinerary.zig").Itinerary;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var itinerary = Itinerary.init(allocator);
    defer itinerary.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try itinerary.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try itinerary.getTotalDistance();
            const expected = @as(usize, 1873376);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try itinerary.getSimilarityScore();
            const expected = @as(usize, 18997088);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
