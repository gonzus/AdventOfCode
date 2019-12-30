const std = @import("std");
const Fabric = @import("./fabric.zig").Fabric;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.heap.direct_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var fabric = Fabric.init();
    defer fabric.deinit();

    var count: usize = 0;
    while (std.io.readLine(&buf)) |line| {
        fabric.add_cut(line);
        count += 1;
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    const output = fabric.find_non_overlapping();
    try out.print("First non-overlapping id for {} cuts: {}\n", count, output);
}
