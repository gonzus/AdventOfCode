const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Cluster = @import("./module.zig").Cluster;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var cluster = Cluster.init(allocator, part == .part2);
    defer cluster.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    var answer: isize = 0;
    switch (part) {
        .part1 => {
            answer = try cluster.getLastFrequencyOnRcv(0);
            const expected = @as(isize, 9423);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try cluster.getSendCountForProgram(1);
            const expected = @as(isize, 7620);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
