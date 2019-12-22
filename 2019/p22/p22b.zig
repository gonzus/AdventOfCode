const std = @import("std");
const Deck = @import("./deck.zig").Deck;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    const size: isize = 119315717514047;
    const runs: isize = 101741582076661;
    const pos: isize = 2020;

    var deck = Deck.init(size);
    defer deck.deinit();

    while (std.io.readLine(&buf)) |line| {
        deck.run_line(line);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }

    // we now have the deck as it stands after one iteration
    // since all the transformations are (mod) linear, we can compute the values after N iterations:
    //
    // step = pow(s0, n, size)
    // first = f0 * (step - 1) / (s0 - 1)     (just like a geometric series)
    //
    // but that is not a real division, it has to be modular, so we multiply by the modular inverse:
    //
    // first = f0 * (step - 1) * inv(s0 - 1)

    const s0 = deck.step;
    const f0 = deck.first;

    const s1 = Deck.mod_power(s0, runs, size);

    var tmp: i128 = f0;
    tmp *= s1 - 1;
    tmp = @mod(tmp, size);
    tmp *= Deck.mod_inverse(s0 - 1, size);
    tmp = @mod(tmp, size);
    const f1 = @intCast(isize, tmp);

    // now just plug those values back into the deck and get the desired card
    deck.step = s1;
    deck.first = f1;
    try out.print("Card in position {} is {}\n", pos, deck.get_card(pos));
}
