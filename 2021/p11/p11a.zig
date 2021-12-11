const std = @import("std");
const Octopus = @import("./octopus.zig").Octopus;

pub fn main() anyerror!void {
    var octopus = Octopus.init();
    defer octopus.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try octopus.process_line(line);
    }

    const steps = 100;
    const total_flashes = octopus.count_total_flashes_after_n_steps(steps);
    const out = std.io.getStdOut().writer();
    try out.print("Total flashes after {} steps: {}\n", .{ steps, total_flashes });
}
