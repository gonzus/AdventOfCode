const std = @import("std");
const Board = @import("./board.zig").Board;

pub fn main() !void {
    var board = Board.init(false);
    defer board.deinit();

    const inp = std.io.getStdIn().reader();
    var count: u32 = 0;
    var buf: [20480]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;
        board.add_line(line);
    }
    const steps = board.run_until_repeated();
    const code = board.encode();
    // board.show();
    std.debug.warn("Found repeated non-recursive board after {} steps, biodiversity is {}\n", .{ steps, code });
}
