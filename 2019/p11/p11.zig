const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Ship = @import("./module.zig").Ship;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var ship = Ship.init(allocator);
    defer ship.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [3 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try ship.addLine(line);
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    switch (part) {
        .part1 => {
            const answer = try ship.paintHull();
            try out.print("Answer: {}\n", .{answer});
            const expected = @as(usize, 1885);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            const answer = try ship.paintIdentifier();
            try out.print("Answer: {s}\n", .{answer});
            const expected = "BFEAGHAF";
            try testing.expectEqualStrings(expected, answer);
        },
    }

    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
