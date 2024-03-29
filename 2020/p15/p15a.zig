const std = @import("std");
const Puzzle = @import("./puzzle.zig").Puzzle;

pub fn main() anyerror!void {
    var puzzle = Puzzle.init(false);
    defer puzzle.deinit();

    const top: usize = 2020;
    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const number = puzzle.run(line, top);
        const out = std.io.getStdOut().writer();
        try out.print("Number: {}\n", .{number});
    }
}
