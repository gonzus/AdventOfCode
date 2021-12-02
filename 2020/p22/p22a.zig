const std = @import("std");
const Game = @import("./game.zig").Game;

pub fn main() anyerror!void {
    var game = Game.init(Game.Mode.Simple);
    defer game.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        game.add_line(line);
    }

    const score = game.play();

    const out = std.io.getStdOut().writer();
    try out.print("Score: {}\n", .{score});
}
