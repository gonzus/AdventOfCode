const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Factory = @import("./module.zig").Factory;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var factory = Factory.init(allocator, part == .part2);
    defer factory.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try factory.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try factory.findShortestSteps();
            const expected = @as(usize, 47);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try factory.findShortestSteps();
            const expected = @as(usize, 71);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
