const std = @import("std");
const Bank = @import("./bank.zig").Bank;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;
        var bank = Bank.init(line);
        bank.setReentrant();
        var phase = [5]u8{ 5, 6, 7, 8, 9 }; // must be sorted
        const result = bank.optimize_thruster_signal(&phase);
        try out.print("Result is {}\n", result);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines\n", count);
}
