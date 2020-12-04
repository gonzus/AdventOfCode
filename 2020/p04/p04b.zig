const std = @import("std");
const Scanner = @import("./scanner.zig").Scanner;

pub fn main() anyerror!void {
    var scanner = Scanner.init(true);
    defer scanner.deinit();

    const inp = std.io.bufferedInStream(std.io.getStdIn().inStream()).inStream();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        scanner.add_line(line);
    }
    scanner.done();

    const count = scanner.valid_count();

    const out = std.io.getStdOut().outStream();
    try out.print("Valid passports: {}\n", .{count});
}
