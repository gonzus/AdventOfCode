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
    const x = 22;
    const y = 25;
    const wanted: usize = 200;
    const result = board.scan_and_blast(x, y, wanted);
    try out.print("Read {} lines, shot #{} from {} {} is {}\n", .{ count, wanted, x, y, result });
}
