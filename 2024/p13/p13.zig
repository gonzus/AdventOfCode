const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Module = @import("./module.zig").Module;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var module = Module.init(allocator, part == .part2);
    defer module.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [20 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try module.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try module.getFewestTokens();
            const expected = @as(usize, 30413);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try module.getFewestTokens();
            const expected = @as(usize, 92827349540204);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}