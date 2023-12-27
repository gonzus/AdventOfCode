const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Coin = @import("./module.zig").Coin;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var coin = try Coin.init();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try coin.addLine(line);
    }

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try coin.findFirstHashWithZeroes(5);
            const expected = @as(usize, 117946);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try coin.findFirstHashWithZeroes(6);
            const expected = @as(usize, 3938038);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
