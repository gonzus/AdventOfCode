const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Spreadsheet = @import("./module.zig").Spreadsheet;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var spreadsheet = Spreadsheet.init(allocator, part == .part2);

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try spreadsheet.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = spreadsheet.getChecksum();
            const expected = @as(usize, 44216);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = spreadsheet.getChecksum();
            const expected = @as(usize, 320);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
