const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Charge = @import("./module.zig").Charge;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var charge = Charge.init();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try charge.addLine(line);
    }

    var answer: []const u8 = undefined;
    switch (part) {
        .part1 => {
            answer = try charge.findBestForSize(3);
            const expected = "20,62";
            try testing.expectEqualStrings(expected, answer);
        },
        .part2 => {
            answer = try charge.findBestForAnySize();
            const expected = "229,61,16";
            try testing.expectEqualStrings(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("Answer: {s}\n", .{answer});
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
