const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Forest = @import("./module.zig").Forest;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var forest = try Forest.init(allocator);
    defer forest.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try forest.addLine(line);
    }
    // forest.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try forest.simulateFor(10);
            const expected = @as(usize, 360720);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try forest.simulateFor(1000000000);
            const expected = @as(usize, 197276);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
