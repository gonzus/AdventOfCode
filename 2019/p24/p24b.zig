const std = @import("std");
const Board = @import("./board.zig").Board;

pub fn main() !void {
    var board = Board.init(true);
    defer board.deinit();

    const inp = std.io.getStdIn().reader();
    var count: u32 = 0;
    var buf: [20480]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;
        board.add_line(line);
    }
    const steps: usize = 200;
    board.run_for_N_steps(steps);
    // board.show();
    const bugs = board.count_bugs();
    std.debug.warn("Found {} bugs in recursive board after {} steps\n", .{ bugs, steps });
}
