const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Module = @import("./module.zig").Module;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var module = Module.init(allocator);
    defer module.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try module.addLine(line);
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    switch (part) {
        .part1 => {
            const answer = try module.getProgramOutput();
            try out.print("Answer: {s}\n", .{answer});
            const expected = "1,6,3,6,5,6,5,1,7";
            try testing.expectEqualStrings(expected, answer);
        },
        .part2 => {
            const answer = try module.findQuine();
            try out.print("Answer: {}\n", .{answer});
            const expected = @as(u128, 247839653009594);
            try testing.expectEqual(expected, answer);
        },
    }

    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
