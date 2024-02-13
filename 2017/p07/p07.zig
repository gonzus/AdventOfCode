const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Tower = @import("./module.zig").Tower;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var tower = Tower.init(allocator);
    defer tower.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try tower.addLine(line);
    }
    // tower.show();

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    switch (part) {
        .part1 => {
            const answer = try tower.findBottomProgram();
            const expected = "cyrupz";
            try testing.expectEqualSlices(u8, expected, answer);
            try out.print("Answer: {s}\n", .{answer});
        },
        .part2 => {
            const answer = try tower.findBalancingWeight();
            const expected = @as(usize, 193);
            try testing.expectEqual(expected, answer);
            try out.print("Answer: {}\n", .{answer});
        },
    }

    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
