const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Chronal = @import("./module.zig").Chronal;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var chronal = Chronal.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try chronal.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = try chronal.findLargestUnsafeArea();
            const expected = @as(usize, 4011);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try chronal.findNearbySafeArea(10000);
            const expected = @as(usize, 46054);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("Answer: {}\n", .{answer});
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
