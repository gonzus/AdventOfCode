const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Garden = @import("./island.zig").Garden;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var garden = Garden.init(allocator, part == .part2);
    defer garden.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try garden.addLine(line);
    }
    // garden.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try garden.getPlotsForSteps(64);
            const expected = @as(usize, 3743);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try garden.getPlotsForSteps(26501365);
            const expected = @as(usize, 618261433219147);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
