const std = @import("std");
const Reactor = @import("./reactor.zig").Reactor;

pub fn main() anyerror!void {
    var reactor = Reactor.init();
    defer reactor.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try reactor.process_line(line);
    }

    const cubes = try reactor.run_reboot();
    const out = std.io.getStdOut().writer();
    try out.print("Cubes on: {}\n", .{cubes});
}
