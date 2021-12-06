const std = @import("std");
const Sleuth = @import("./sleuth.zig").Sleuth;

pub fn main() !void {
    var sleuth = Sleuth.init(Sleuth.Match.TwoOrMore);

    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const count = sleuth.search(line);
        try out.print("Found {} matches between {} and {}\n", .{ count, sleuth.lo, sleuth.hi });
    }
}
