const std = @import("std");
const Submarine = @import("./submarine.zig").Submarine;

pub fn main() anyerror!void {
    var submarine = Submarine.init(Submarine.Mode.Complex);
    defer submarine.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        submarine.process_command(line);
    }

    const pos = submarine.get_position();
    const out = std.io.getStdOut().writer();
    try out.print("Position for complex movement: {}\n", .{pos});
}
