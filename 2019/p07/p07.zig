const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Cluster = @import("./module.zig").Cluster;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var cluster = Cluster.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [2 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try cluster.addLine(line);
    }

    var answer: isize = undefined;
    switch (part) {
        .part1 => {
            answer = try cluster.optimizeSignal(false);
            const expected = @as(isize, 79723);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try cluster.optimizeSignal(true);
            const expected = @as(isize, 70602018);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
