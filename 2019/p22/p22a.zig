const std = @import("std");
const Deck = @import("./deck.zig").Deck;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    const size: isize = 10007;
    const card: isize = 2019;

    var deck = Deck.init(size);
    defer deck.deinit();

    while (std.io.readLine(&buf)) |line| {
        deck.run_line(line);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    const pos = deck.get_pos(card);
    try out.print("Position for card {} is {}\n", card, pos);
}
