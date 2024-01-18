const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Sleigh = @import("./module.zig").Sleigh;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var sleigh = Sleigh.init(allocator);
    defer sleigh.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try sleigh.addLine(line);
    }
    // sleigh.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = sleigh.findSmallestEntanglement(3);
            const expected = @as(usize, 11266889531);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = sleigh.findSmallestEntanglement(4);
            const expected = @as(usize, 77387711);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
