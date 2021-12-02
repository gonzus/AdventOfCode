const std = @import("std");
const Password = @import("./password.zig").Password;

pub fn main() anyerror!void {
    var password = Password.init();
    defer password.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    var count: usize = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        if (password.check_pos(line)) {
            count += 1;
        }
    }

    const out = std.io.getStdOut().writer();
    try out.print("Good passwords: {}\n", .{count});
}
