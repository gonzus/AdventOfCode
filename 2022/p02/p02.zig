const std = @import("std");
const command = @import("./util/command.zig");
const Game = @import("./game.zig").Game;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var game = Game.init(allocator);
    defer game.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try game.add_line(line);
    }

    const score = game.get_score(part == 2);
    const out = std.io.getStdOut().writer();
    try out.print("Score: {}\n", .{score});
    return 0;
}
