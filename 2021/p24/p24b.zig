const std = @import("std");
const ALU = @import("./alu.zig").ALU;

pub fn main() anyerror!void {
    var alu = ALU.init();
    defer alu.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try alu.process_line(line);
    }

    const num = try alu.search_min();
    const out = std.io.getStdOut().writer();
    try out.print("Min number: {}\n", .{num});
}
