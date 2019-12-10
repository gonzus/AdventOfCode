const std = @import("std");
const Board = @import("./board.zig").Board;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var board = Board.init();
    defer board.deinit();

    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;
        board.add_line(line);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    const wanted: usize = 200;
    const result = board.scan_and_blast(26, 28, wanted);
    try out.print("Read {} lines, shot #{} is {}\n", count, wanted, result);
}
