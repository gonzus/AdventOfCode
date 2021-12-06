const std = @import("std");
const Bank = @import("./bank.zig").Bank;

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    var count: u32 = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;
        var bank = Bank.init(line);
        defer bank.deinit();

        var phase = [5]u8{ 0, 1, 2, 3, 4 }; // must be sorted
        const result = bank.optimize_thruster_signal(&phase);
        try out.print("Result is {}\n", .{result});
    }
    try out.print("Read {} lines\n", .{count});
}
