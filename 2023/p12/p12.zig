const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Record = @import("./island.zig").Record;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var record = Record.init(allocator, if (part == .part2) 5 else 1);
    defer record.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try record.addLine(line);
        // record.show();
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try record.getSumArrangements();
            const expected = @as(usize, 7017);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try record.getSumArrangements();
            const expected = @as(usize, 527570479489);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
