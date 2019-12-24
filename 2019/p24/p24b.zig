const std = @import("std");
const Board = @import("./board.zig").Board;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.heap.direct_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var board = Board.init(true);
    defer board.deinit();

    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;
        board.add_line(line);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    const steps: usize = 200;
    board.run_for_N_steps(steps);
    // board.show();
    const bugs = board.count_bugs();
    std.debug.warn("Found {} bugs in recursive board after {} steps\n", bugs, steps);
}
