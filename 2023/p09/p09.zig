const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Sensor = @import("./island.zig").Sensor;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var sensor = Sensor.init(allocator);
    defer sensor.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try sensor.addLine(line);
    }
    // sensor.show();

    var answer: isize = 0;
    switch (part) {
        .part1 => {
            answer = try sensor.getEndSum();
            const expected = @as(isize, 1901217887);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try sensor.getBegSum();
            const expected = @as(isize, 905);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
