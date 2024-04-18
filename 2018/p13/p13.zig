const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Mine = @import("./module.zig").Mine;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var mine = Mine.init(allocator);
    defer mine.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try mine.addLine(line);
    }
    // mine.show();

    var answer = Mine.Pos.init();
    switch (part) {
        .part1 => {
            answer = try mine.runUntilCrash();
            const expected = Mine.Pos.copy(&[_]usize{ 57, 104 });
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try mine.runUntilOneCart();
            const expected = Mine.Pos.copy(&[_]usize{ 67, 74 });
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("Answer: {}\n", .{answer});
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
