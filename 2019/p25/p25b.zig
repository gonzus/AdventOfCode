const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    try out.print("Good job on Advent of Code 2019!\n");
}
