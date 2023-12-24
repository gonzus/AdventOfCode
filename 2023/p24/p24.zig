const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Air = @import("./island.zig").Air;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var air = Air.init(allocator);
    defer air.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try air.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try air.getIntersectingHailstonesInArea(200000000000000, 400000000000000);
            const expected = @as(usize, 23760);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try air.findSumPosHittingRock();
            const expected = @as(usize, 888708704663413);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
