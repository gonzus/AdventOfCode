const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Promenade = @import("./module.zig").Promenade;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var promenade = Promenade.init(allocator, 0);
    defer promenade.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [50 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try promenade.addLine(line);
    }

    var answer: []const u8 = undefined;
    switch (part) {
        .part1 => {
            answer = try promenade.runMovesTimes(1);
            const expected = "kbednhopmfcjilag";
            try testing.expectEqualSlices(u8, expected, answer);
        },
        .part2 => {
            answer = try promenade.runMovesTimes(1_000_000_000);
            const expected = "fbmcgdnjakpioelh";
            try testing.expectEqualSlices(u8, expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {s}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
