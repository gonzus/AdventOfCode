const std = @import("std");
const Octopus = @import("./octopus.zig").Octopus;

pub fn main() !void {
    var octopus = Octopus.init();
    defer octopus.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try octopus.process_line(line);
    }

    const steps = octopus.count_steps_until_simultaneous_flash();
    const out = std.io.getStdOut().writer();
    try out.print("Steps until simultaneous flash: {}\n", .{steps});
}
