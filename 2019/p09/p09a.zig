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

        var computer = Computer.init(true);
        defer computer.deinit();

        computer.parse(line);
        computer.enqueueInput(1);
        computer.run();

        try out.print("Line {}, {} total outputs\n", count, computer.outputs.pw);
        var j: usize = 0;
        while (j < computer.outputs.pw) : (j += 1) {
            try out.print("  {}: {}\n", j, computer.outputs.data[j]);
        }
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines\n", count);
}
