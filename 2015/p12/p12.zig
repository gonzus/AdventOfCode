const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Document = @import("./module.zig").Document;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var document = Document.init(allocator, part == .part2);
    defer document.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024 * 50]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try document.addLine(line);
    }

    var answer: isize = 0;
    switch (part) {
        .part1 => {
            answer = try document.getSumOfNumbers();
            const expected = @as(isize, 156366);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try document.getSumOfNumbers();
            const expected = @as(isize, 96852);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
