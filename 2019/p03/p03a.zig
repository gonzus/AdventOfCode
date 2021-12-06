const std = @import("std");
const Board = @import("./board.zig").Board;

pub fn main() !void {
    var board = Board.init(Board.Distance.Manhattan);
    defer board.deinit();

    const inp = std.io.getStdIn().reader();
    var count: u32 = 0;
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;
        board.trace(line, count == 1);
    }

    const out = std.io.getStdOut().writer();
    try out.print("Read {} lines, min {} at {} {}\n", .{ count, board.md, board.mx, board.my });
}
