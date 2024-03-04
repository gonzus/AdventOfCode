const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Routing = @import("./module.zig").Routing;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var routing = Routing.init(allocator);
    defer routing.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try routing.addLine(line);
    }
    // routing.show();

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    switch (part) {
        .part1 => {
            const answer = try routing.findLetters();
            const expected = "PVBSCMEQHY";
            try testing.expectEqualStrings(expected, answer);
            try out.print("Answer: {s}\n", .{answer});
        },
        .part2 => {
            const answer = try routing.countSteps();
            const expected = @as(usize, 17736);
            try testing.expectEqual(expected, answer);
            try out.print("Answer: {}\n", .{answer});
        },
    }

    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
