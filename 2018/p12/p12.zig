const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Tunnel = @import("./module.zig").Tunnel;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var tunnel = Tunnel.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try tunnel.addLine(line);
    }

    var answer: isize = 0;
    switch (part) {
        .part1 => {
            answer = try tunnel.runIterations(20);
            const expected = @as(isize, 3798);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try tunnel.runIterations(50000000000);
            const expected = @as(isize, 3900000002212);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
