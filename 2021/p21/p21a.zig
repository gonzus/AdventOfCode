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

    game.deterministic_play_until_win(1000);
    const score = game.deterministic_weigthed_score_looser();
    const out = std.io.getStdOut().writer();
    try out.print("Score: {}\n", .{score});
}
