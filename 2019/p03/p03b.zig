const std = @import("std");
const Board = @import("./board.zig").Board;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var board = Board.init(Board.Distance.Travelled);
    defer board.destroy();

    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;
        board.trace(line, count == 1);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines, min {} at {} {}\n", count, board.md, board.mx, board.my);
}
