const std = @import("std");
const Game = @import("./game.zig").Game;

pub fn main() anyerror!void {
    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var game = Game.init(line, Game.SIZE);
        defer game.deinit();
        // game.show();

        game.play(10_000_000);
        const stars = game.find_stars();
        try out.print("Stars: {}\n", .{stars});
    }
}
