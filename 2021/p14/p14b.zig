const std = @import("std");
const Polymer = @import("./polymer.zig").Polymer;

pub fn main() anyerror!void {
    var polymer = Polymer.init();
    defer polymer.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try polymer.process_line(line);
    }

    const steps = 40;
    const diff_top_elements = try polymer.get_diff_top_elements_after_n_steps(steps);
    const out = std.io.getStdOut().writer();
    try out.print("Difference between top elements after {} steps: {}\n", .{ steps, diff_top_elements });
}
