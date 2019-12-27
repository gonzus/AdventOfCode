const std = @import("std");
const Accum = @import("./accum.zig").Accum;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var accum = Accum.init();
    defer accum.deinit();

    while (std.io.readLine(&buf)) |line| {
        accum.parse(line);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("First repetition is {}\n", accum.find_first_repetition());
}
