const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var count: u32 = 0;
    var sum: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;
        const mass: u32 = try std.fmt.parseInt(u32, line, 10);
        const value = mass / 3 - 2;
        // try out.print("Value: {}\n", value);
        sum += value;
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Simple process: {} records that sum to {}\n", count, sum);
}
