const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Pattern = @import("./island.zig").Pattern;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var pattern = Pattern.init(allocator, if (part == .part2) 1 else 0);
    defer pattern.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try pattern.addLine(line);
        // pattern.show();
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try pattern.getSummary();
            const expected = @as(usize, 36015);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try pattern.getSummary();
            const expected = @as(usize, 35335);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
