const std = @import("std");
const Computer = @import("./computer.zig").Computer;

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [20480]u8 = undefined;
    var count: u32 = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;

        var computer = Computer.init(true);
        defer computer.deinit();

        computer.parse(line);
        computer.enqueueInput(1);
        computer.run();

        try out.print("Line {}, {} total outputs\n", .{ count, computer.outputs.pw });
        var j: usize = 0;
        while (j < computer.outputs.pw) : (j += 1) {
            try out.print("  {}: {}\n", .{ j, computer.outputs.data[j] });
        }
    }
    try out.print("Read {} lines\n", .{count});
}
