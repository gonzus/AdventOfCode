const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Room = @import("./module.zig").Room;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var room = Room.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try room.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try room.getSafeTiles(40);
            const expected = @as(usize, 1961);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try room.getSafeTiles(400000);
            const expected = @as(usize, 20000795);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
