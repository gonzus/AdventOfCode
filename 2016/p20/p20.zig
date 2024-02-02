const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Firewall = @import("./module.zig").Firewall;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var firewall = Firewall.init(allocator, 0);
    defer firewall.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try firewall.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try firewall.getLowestAdressAllowed();
            const expected = @as(usize, 32259706);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try firewall.getAllowedAdressCount();
            const expected = @as(usize, 113);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
