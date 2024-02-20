const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Disk = @import("./module.zig").Disk;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var disk = Disk.init(allocator);
    defer disk.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try disk.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = try disk.getUsedSquares();
            const expected = @as(usize, 8316);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try disk.countRegions();
            const expected = @as(usize, 1074);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
