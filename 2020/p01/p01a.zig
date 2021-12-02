const std = @import("std");
const Checker = @import("./checker.zig").Checker;

pub fn main() anyerror!void {
    var checker = Checker.init();
    defer checker.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const value = std.fmt.parseInt(i32, line, 10) catch unreachable;
        checker.add(value);
    }

    const out = std.io.getStdOut().writer();
    const wanted = 2020;
    const product = checker.check2(wanted);
    try out.print("{} with 2 => {}\n", .{ wanted, product });
}
