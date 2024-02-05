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
    defer cluster.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = try cluster.getViableNodes();
            const expected = @as(usize, 1020);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try cluster.getMovesNeeded();
            const expected = @as(usize, 198);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
