const std = @import("std");
const Factory = @import("./factory.zig").Factory;

pub fn main() !void {
    var factory = Factory.init();
    defer factory.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [20480]u8 = undefined;
    var count: u32 = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;
        factory.parse(line);
    }
    const needed = factory.ore_needed_for_fuel(1);
    const out = std.io.getStdOut().writer();
    try out.print("Needed {} ore\n", .{needed});
}
