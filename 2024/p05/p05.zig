const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Printer = @import("./printer.zig").Printer;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var printer = Printer.init(allocator, part == .part2);
    defer printer.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try printer.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try printer.sumMiddlePages();
            const expected = @as(usize, 4957);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try printer.sumMiddlePages();
            const expected = @as(usize, 6938);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
