const std = @import("std");
const Computer = @import("./computer.zig").Computer;

pub fn main() anyerror!void {
    var computer = Computer.init();
    defer computer.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try computer.process_line(line);
    }

    const sum = try computer.get_sum_of_versions();
    const out = std.io.getStdOut().writer();
    try out.print("Sum of versions: {}\n", .{sum});
}
