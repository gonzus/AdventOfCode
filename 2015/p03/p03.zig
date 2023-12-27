const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Map = @import("./module.zig").Map;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var map = try Map.init(allocator, if (part == .part1) 1 else 2);
    defer map.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try map.addLine(line);
    }
    // map.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = map.getTotalHousesVisited();
            const expected = @as(usize, 2592);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = map.getTotalHousesVisited();
            const expected = @as(usize, 2360);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
