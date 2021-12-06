const std = @import("std");
const Deck = @import("./deck.zig").Deck;

pub fn main() !void {
    const size: isize = 10007;
    const card: isize = 2019;

    var deck = Deck.init(size);
    defer deck.deinit();

    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [20480]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        deck.run_line(line);
    }
    const pos = deck.get_pos(card);
    try out.print("Position for card {} is {}\n", .{ card, pos });
}
