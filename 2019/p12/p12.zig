const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Map = @import("./module.zig").Map;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var map = Map.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [2 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try map.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = try map.getEnergyAfterSteps(1000);
            const expected = @as(usize, 14809);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try map.getFinalCycleSize();
            const expected = @as(usize, 282270365571288);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
