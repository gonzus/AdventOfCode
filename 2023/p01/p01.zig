const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Calibration = @import("./trebuchet.zig").Calibration;

pub fn main() anyerror!u8 {
    const part = command.choosePart();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const only_digits = part == .part1;
    var calibration = Calibration.init(allocator, only_digits);
    defer calibration.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try calibration.addLine(line);
    }

    var sum: usize = 0;
    switch (part) {
        .part1 => {
            sum = calibration.getSum();
            const expected = @as(usize, 54450);
            try testing.expectEqual(expected, sum);
        },
        .part2 => {
            sum = calibration.getSum();
            const expected = @as(usize, 54265);
            try testing.expectEqual(expected, sum);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("Sum: {}\n", .{sum});
    return 0;
}
