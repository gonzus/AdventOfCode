const std = @import("std");

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    try out.print("Good job on Advent of Code 2019!\n", .{});
}
