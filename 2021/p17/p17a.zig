const std = @import("std");
const Probe = @import("./probe.zig").Probe;

pub fn main() anyerror!void {
    var probe = Probe.init();
    defer probe.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try probe.process_line(line);
    }

    const highest = probe.find_highest_position();
    const out = std.io.getStdOut().writer();
    try out.print("Highest y: {}\n", .{highest});
}
