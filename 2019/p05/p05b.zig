const std = @import("std");
const Computer = @import("./computer.zig").Computer;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;
        var computer = Computer.init(line);
        for (args) |arg, pos| {
            if (pos == 0) continue;
            const input = try std.fmt.parseInt(i32, arg, 10);
            const result = computer.run(input);
            try out.print("Result for {} is {}\n", input, result);
        }
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines\n", count);
}
