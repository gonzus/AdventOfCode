const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Grid = @import("./gondola.zig").Grid;

pub fn main() anyerror!u8 {
    const part = command.choosePart();

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var grid = Grid.init(allocator);
    defer grid.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try grid.addLine(line);
    }

    var sum: usize = 0;
    switch (part) {
        .part1 => {
            sum = try grid.getSumPartNumbers();
            const expected = @as(usize, 520135);
            try testing.expectEqual(expected, sum);
        },
        .part2 => {
            sum = try grid.getSumGearRatios();
            const expected = @as(usize, 72514855);
            try testing.expectEqual(expected, sum);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("Sum: {}\n", .{sum});
    return 0;
}
