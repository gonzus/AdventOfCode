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
        const input: i32 = 5;
        const result: i32 = computer.run(input);
        try out.print("Result for {} is {}\n", input, result);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines\n", count);
}
