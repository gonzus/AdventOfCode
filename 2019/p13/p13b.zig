const std = @import("std");
const Board = @import("./board.zig").Board;

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [20480]u8 = undefined;
    var count: u32 = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;

        var board = Board.init(true);
        defer board.deinit();

        board.parse(line);
        board.run();
        try out.print("Line {}, last score is {}\n", .{ count, board.score });
    }
    try out.print("Read {} lines\n", .{count});
}
