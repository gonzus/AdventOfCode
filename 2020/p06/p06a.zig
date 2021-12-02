const std = @import("std");
const Customs = @import("./customs.zig").Customs;

pub fn main() anyerror!void {
    var customs = Customs.init(true);
    defer customs.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        customs.add_line(line);
    }
    customs.done();

    const total_sum = customs.get_total_sum();

    const out = std.io.getStdOut().writer();
    try out.print("Total sum ANY: {}\n", .{total_sum});
}
