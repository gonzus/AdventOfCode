const std = @import("std");
const Decoder = @import("./decoder.zig").Decoder;

pub fn main() anyerror!void {
    var decoder = Decoder.init(Decoder.Mode.Address);
    defer decoder.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        decoder.add_line(line);
    }

    const sum = decoder.sum_all_values();

    const out = std.io.getStdOut().writer();
    try out.print("Sum: {}\n", .{sum});
}
