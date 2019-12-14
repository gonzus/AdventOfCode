const std = @import("std");
const Factory = @import("./factory.zig").Factory;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var factory = Factory.init();
    defer factory.deinit();

    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;
        factory.parse(line);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    const result = factory.fuel_possible(1000000000000);
    try out.print("Can make {} fuel\n", result);
}
