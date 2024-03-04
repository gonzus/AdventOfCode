const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Screen = @import("./module.zig").Screen;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var screen = try Screen.init(allocator, 6, 50);
    defer screen.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try screen.addLine(line);
        // screen.show();
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    switch (part) {
        .part1 => {
            const answer = screen.getLitPixels();
            const expected = @as(usize, 116);
            try testing.expectEqual(expected, answer);
            try out.print("Answer: {}\n", .{answer});
        },
        .part2 => {
            const answer = screen.displayMessage(&buf);
            const expected = "UPOJFLBCEZ";
            try testing.expectEqualStrings(expected, answer);
            try out.print("Answer: {s}\n", .{answer});
        },
    }
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
