const std = @import("std");
const Game = @import("./game.zig").Game;

pub fn main() anyerror!void {
    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        var game = Game.init(line, 0);
        defer game.deinit();
        // game.show();

        game.play(100);
        const state = game.get_state();
        try out.print("State: {}\n", .{state});
    }
}
