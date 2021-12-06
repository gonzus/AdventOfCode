const std = @import("std");
const Computer = @import("./computer.zig").Computer;

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    var count: u32 = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;
        var computer = Computer.init(line);
        const input: i32 = 5;
        const result = computer.run(input);
        try out.print("Result for {} is {}\n", .{ input, result });
    }
    try out.print("Read {} lines\n", .{count});
}
