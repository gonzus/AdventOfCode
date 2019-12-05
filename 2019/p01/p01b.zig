const std = @import("std");
const Tank = @import("./tank.zig").Tank;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var tank = Tank.init();
    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;
        _ = tank.parse(line, true);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Corrected for fuel: {} records that sum to {}\n", count, tank.get());
}
