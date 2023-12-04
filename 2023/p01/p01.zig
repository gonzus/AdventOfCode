const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Calibration = @import("./trebuchet.zig").Calibration;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    const only_digits = part == .part1;
    var calibration = Calibration.init(allocator, only_digits);
    defer calibration.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try calibration.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = calibration.getSum();
            const expected = @as(usize, 54450);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = calibration.getSum();
            const expected = @as(usize, 54265);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
