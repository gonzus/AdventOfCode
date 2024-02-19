const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Village = @import("./module.zig").Village;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var village = Village.init(allocator);
    defer village.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [30 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try village.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = try village.getGroupSize(0);
            const expected = @as(usize, 306);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try village.getGroupCount();
            const expected = @as(usize, 200);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
