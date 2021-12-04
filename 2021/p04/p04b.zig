const std = @import("std");
const Bingo = @import("./bingo.zig").Bingo;

pub fn main() anyerror!void {
    var bingo = Bingo.init();
    defer bingo.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        bingo.process_line(line);
    }

    const score = bingo.play_until_last_win();
    const out = std.io.getStdOut().writer();
    try out.print("Score for last win: {}\n", .{score});
}
