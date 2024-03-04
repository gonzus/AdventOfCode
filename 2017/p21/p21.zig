const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Canvas = @import("./module.zig").Canvas;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var canvas = Canvas.init(allocator);
    defer canvas.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try canvas.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = try canvas.runIterations(4);
            const expected = @as(usize, 81);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try canvas.runIterations(18);
            const expected = @as(usize, 1879071);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
