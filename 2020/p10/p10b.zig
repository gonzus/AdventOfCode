const std = @import("std");
const Adapter = @import("./adapter.zig").Adapter;

pub fn main() anyerror!void {
    var adapter = Adapter.init();
    defer adapter.deinit();

    const inp = std.io.bufferedInStream(std.io.getStdIn().inStream()).inStream();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        adapter.add_rating(line);
    }

    const valid = adapter.count_valid();

    const out = std.io.getStdOut().outStream();
    try out.print("Valid = {}\n", .{valid});
}
