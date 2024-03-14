const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Security = @import("./module.zig").Security;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var security = Security.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try security.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = try security.getMostAsleep(1);
            const expected = @as(usize, 104764);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try security.getMostAsleep(2);
            const expected = @as(usize, 128617);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("Answer: {}\n", .{answer});
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
