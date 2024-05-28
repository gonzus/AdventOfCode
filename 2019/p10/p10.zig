const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Board = @import("./module.zig").Board;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var board = Board.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try board.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = try board.getAsteroidCountFromBestPosition();
            const expected = @as(usize, 286);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try board.scanAndBlastFromBestPosition(200);
            const expected = @as(usize, 504);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
