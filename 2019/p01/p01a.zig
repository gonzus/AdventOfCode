const std = @import("std");
const Tank = @import("./tank.zig").Tank;

pub fn main() !void {
    var tank = Tank.init();
    defer tank.deinit();

    const inp = std.io.getStdIn().reader();
    var count: u32 = 0;
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;
        _ = tank.parse(line, false);
    }

    const out = std.io.getStdOut().writer();
    try out.print("Simple process: {} records that sum to {}\n", .{ count, tank.get() });
}
