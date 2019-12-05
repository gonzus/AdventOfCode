const std = @import("std");
const Sleuth = @import("./sleuth.zig").Sleuth;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var sleuth = Sleuth.init(Sleuth.Match.TwoOnly);

    while (std.io.readLine(&buf)) |line| {
        const count = sleuth.search(line);
        try out.print("Found {} matches between {} and {}\n", count, sleuth.lo, sleuth.hi);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
}
