const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const FFT = @import("./module.zig").FFT;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var fft = FFT.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try fft.addLine(line);
    }

    var answer: []const u8 = undefined;
    switch (part) {
        .part1 => {
            answer = try fft.getSignal(100, 1, false);
            const expected = "44098263";
            try testing.expectEqualStrings(expected, answer);
        },
        .part2 => {
            answer = try fft.getSignal(100, 10_000, true);
            const expected = "12482168";
            try testing.expectEqualStrings(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {s}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
