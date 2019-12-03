const std = @import("std");
const Computer = @import("./computer.zig").Computer;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
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
                try out.print("noun {}, verb {} => {} -- encoded as {}\n", noun, verb, zero, coded);
            }
        }
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines\n", count);
}
