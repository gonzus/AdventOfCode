const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Vault = @import("./module.zig").Vault;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var vault = Vault.init(allocator, part == .part2);

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try vault.addLine(line);
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    switch (part) {
        .part1 => {
            const path = try vault.findShortestPath();
            const expected = "RLRDRDUDDR";
            try testing.expectEqualStrings(expected, path);
            try out.print("Answer: {s}\n", .{path});
        },
        .part2 => {
            const length = try vault.findLongestPathLength();
            const expected = @as(usize, 420);
            try testing.expectEqual(expected, length);
            try out.print("Answer: {}\n", .{length});
        },
    }

    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
