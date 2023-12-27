const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Building = @import("./module.zig").Building;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var building = Building.init();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    var answer: isize = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        switch (part) {
            .part1 => {
                answer = try building.moveSanta(line);
                const expected = @as(isize, 74);
                try testing.expectEqual(expected, answer);
            },
            .part2 => {
                answer = try building.stepsUntilSantaIsInBasement(line);
                const expected = @as(isize, 1795);
                try testing.expectEqual(expected, answer);
            },
        }
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
