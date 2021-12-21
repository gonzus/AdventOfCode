const std = @import("std");
const Game = @import("./game.zig").Game;

pub fn main() anyerror!void {
    var game = Game.init();
    defer game.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try game.process_line(line);
    }

    const best = game.dirac_best_score();
    const out = std.io.getStdOut().writer();
    try out.print("Best score: {}\n", .{best});
}
