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
        defer computer.deinit();
        computer.setReentrant();

        computer.enqueueInput(2);
        while (true) {
            computer.run();
            if (computer.halted) break;
        }
        var j: usize = 0;
        while (j < computer.outputs.pw) : (j += 1) {
            std.debug.warn("{}\n", computer.outputs.data[j]);
        }
        std.debug.warn("DONE\n");
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines\n", count);
}
