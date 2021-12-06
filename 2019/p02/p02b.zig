const std = @import("std");
const Computer = @import("./computer.zig").Computer;

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var count: u32 = 0;
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;
        var computer = Computer.init(line);

        const wanted = 19690720;
        var noun: u8 = 0;
        while (noun <= 99) : (noun += 1) {
            var verb: u8 = 0;
            while (verb <= 99) : (verb += 1) {
                var sim = computer;
                sim.set(1, noun);
                sim.set(2, verb);
                sim.run();
                const zero = sim.get(0);
                if (zero != wanted) {
                    continue;
                }
                const coded: u16 = @intCast(u16, noun) * 100 + verb;
                // const coded: u64 = 0;
                try out.print("noun {}, verb {} => {} -- encoded as {}\n", .{ noun, verb, zero, coded });
            }
        }
    }
    try out.print("Read {} lines\n", .{count});
}
