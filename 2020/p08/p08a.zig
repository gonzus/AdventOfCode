const std = @import("std");
const Computer = @import("./computer.zig").Computer;

pub fn main() anyerror!void {
    var computer = Computer.init();
    defer computer.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        computer.add_instr(line);
    }

    _ = computer.run_to_first_dupe();
    const accum = computer.get_accumulator();

    const out = std.io.getStdOut().writer();
    try out.print("Accum: {}\n", .{accum});
}
