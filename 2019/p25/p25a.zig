const std = @import("std");
const Maze = @import("./maze.zig").Maze;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.heap.direct_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var maze = Maze.init();
    defer maze.deinit();

    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;
        maze.computer.parse(line);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    const password = maze.run_to_solve();
    try out.print("Santa said password was {}\n", password);
}
