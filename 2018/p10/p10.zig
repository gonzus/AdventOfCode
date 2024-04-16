const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Message = @import("./module.zig").Message;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var message = Message.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try message.addLine(line);
    }

    const out = std.io.getStdOut().writer();
    switch (part) {
        .part1 => {
            _ = try message.findMessage();
            try message.displayLights();
            const expected = "RBCZAEPP";
            try out.print("That should be: [{s}]\n", .{expected});
        },
        .part2 => {
            const answer: usize = try message.findMessage();
            const expected = @as(usize, 10076);
            try testing.expectEqual(expected, answer);
            try out.print("Answer: {}\n", .{answer});
        },
    }

    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
