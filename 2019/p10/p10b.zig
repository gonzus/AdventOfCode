const std = @import("std");
const Board = @import("./board.zig").Board;

pub fn main() !void {
    var board = Board.init();
    defer board.deinit();

    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [20480]u8 = undefined;
    var count: u32 = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;
        board.add_line(line);
    }
    const wanted: usize = 200;
    const result = board.scan_and_blast(26, 28, wanted);
    try out.print("Read {} lines, shot #{} is {}\n", .{ count, wanted, result });
}
