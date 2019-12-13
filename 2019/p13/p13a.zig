const std = @import("std");
const Board = @import("./board.zig").Board;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;

        var board = Board.init(false);
        defer board.deinit();

        board.parse(line);
        board.run();
        const result = board.count_tiles(Board.Tile.Block);
        try out.print("Line {}, counted {} {} tiles\n", count, result, Board.Tile.Block);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines\n", count);
}
