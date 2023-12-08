const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Network = @import("./island.zig").Network;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var network = Network.init(allocator, part == .part2);
    defer network.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try network.addLine(line);
    }
    // network.show();

    var answer: u64 = 0;
    switch (part) {
        .part1 => {
            answer = try network.getStepsToTraverse();
            const expected = @as(usize, 13301);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try network.getStepsToTraverse();
            const expected = @as(usize, 7309459565207);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
