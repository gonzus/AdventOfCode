const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Disk = @import("./disk.zig").Disk;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var disk = Disk.init(allocator, part == .part2);
    defer disk.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [20 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try disk.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try disk.computeChecksum();
            const expected = @as(usize, 6200294120911);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try disk.computeChecksum();
            const expected = @as(usize, 6227018762750);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
