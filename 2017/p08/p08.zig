const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const CPU = @import("./module.zig").CPU;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var cpu = CPU.init(allocator);
    defer cpu.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try cpu.addLine(line);
    }

    var answer: isize = undefined;
    switch (part) {
        .part1 => {
            // 4074 too low
            answer = try cpu.getLargestRegister();
            const expected = @as(isize, 6012);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try cpu.getHighestValue();
            const expected = @as(isize, 6369);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
