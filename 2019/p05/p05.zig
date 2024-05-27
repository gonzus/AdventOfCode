const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Computer = @import("./module.zig").Computer;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var computer = Computer.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [3 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try computer.addLine(line);
    }

    var answer: isize = undefined;
    switch (part) {
        .part1 => {
            answer = try computer.runWithInput(1);
            const expected = @as(isize, 12440243);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try computer.runWithInput(5);
            const expected = @as(isize, 15486302);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
