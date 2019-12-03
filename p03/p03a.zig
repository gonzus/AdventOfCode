const std = @import("std");
const Board = @import("./board.zig").Board;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var board = Board.init();
    defer board.destroy();

    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;
        try board.trace(line, count == 1, dist);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines, min {} at {} {}\n", count, board.md, board.mx, board.my);
}

fn dist(x: i32, y: i32, v0: u32, v1: u32) u32 {
    const ax = std.math.absInt(x) catch 0;
    const ay = std.math.absInt(y) catch 0;
    return @intCast(u32, ax) + @intCast(u32, ay);
}
