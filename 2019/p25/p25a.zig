const std = @import("std");
const Maze = @import("./maze.zig").Maze;

pub fn main() !void {
    var maze = Maze.init();
    defer maze.deinit();

    const inp = std.io.getStdIn().reader();
    var count: u32 = 0;
    var buf: [20480]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;
        maze.computer.parse(line);
    }
    const password = maze.run_to_solve();
    const out = std.io.getStdOut().writer();
    try out.print("Santa said password was {}\n", .{password});
}
