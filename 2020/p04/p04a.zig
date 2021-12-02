const std = @import("std");
const Scanner = @import("./scanner.zig").Scanner;

pub fn main() anyerror!void {
    var scanner = Scanner.init(false);
    defer scanner.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        scanner.add_line(line);
    }
    scanner.done();

    const count = scanner.valid_count();

    const out = std.io.getStdOut().writer();
    try out.print("Valid passports: {}\n", .{count});
}
