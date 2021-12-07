const std = @import("std");
const Crab = @import("./crab.zig").Crab;

pub fn main() anyerror!void {
    var crab = Crab.init(Crab.Mode.Sum);
    defer crab.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        crab.process_line(line);
    }

    const min = crab.find_min_fuel_consumption();
    const out = std.io.getStdOut().writer();
    try out.print("Minimum fuel: {}\n", .{min});
}
