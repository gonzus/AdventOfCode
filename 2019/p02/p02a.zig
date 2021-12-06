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
        computer.set(1, 12);
        computer.set(2, 2);
        computer.run();
        const zero = computer.get(0);

        try out.print("Mem[0] = {}\n", .{zero});
    }

    try out.print("Read {} lines\n", .{count});
}
