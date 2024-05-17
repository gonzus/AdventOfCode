const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Base = @import("./module.zig").Base;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var base = try Base.init(allocator);
    defer base.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [16 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try base.addLine(line);
    }
    // base.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try base.getMaxDoors();
            const expected = @as(usize, 3983);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try base.getRoomsThatNeedDoors(1000);
            const expected = @as(usize, 8486);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
