const std = @import("std");
const Luggage = @import("./luggage.zig").Luggage;

pub fn main() anyerror!void {
    var luggage = Luggage.init();
    defer luggage.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        luggage.add_rule(line);
    }
    luggage.compute_parents();

    const containers = luggage.sum_can_contain("shiny gold");

    const out = std.io.getStdOut().writer();
    try out.print("Total containers: {}\n", .{containers});
}
