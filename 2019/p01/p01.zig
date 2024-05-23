const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Tank = @import("./module.zig").Tank;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var tank = Tank.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try tank.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = tank.getTotalFuelRequirements(false);
            const expected = @as(usize, 3234871);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = tank.getTotalFuelRequirements(true);
            const expected = @as(usize, 4849444);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("Answer: {}\n", .{answer});
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
