const std = @import("std");

pub fn main() anyerror!void {
    const out = std.io.getStdOut().writer();
    try out.print("DONE\n", .{});
}
