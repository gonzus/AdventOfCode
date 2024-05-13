const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Reservoir = @import("./module.zig").Reservoir;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var reservoir = Reservoir.init(allocator);
    defer reservoir.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try reservoir.addLine(line);
    }
    // reservoir.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try reservoir.getReachableTiles();
            const expected = @as(usize, 34775);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try reservoir.getRemainingTiles();
            const expected = @as(usize, 27086);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
