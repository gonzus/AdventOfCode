const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Module = @import("./module.zig").Module;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var module = Module.init(allocator);
    defer module.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try module.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try module.getPossibleDesigns();
            const expected = @as(usize, 304);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            // 262110840700748 too low
            answer = try module.getTotalWaysForDesigns();
            const expected = @as(usize, 705756472327497);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}