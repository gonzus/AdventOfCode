const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Vault = @import("./module.zig").Vault;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var vault = Vault.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [5 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try vault.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = try vault.collectAllKeys();
            const expected = @as(usize, 4228);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = 0;
            const expected = @as(usize, 1858);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
