const std = @import("std");
const Adapter = @import("./adapter.zig").Adapter;

pub fn main() anyerror!void {
    var adapter = Adapter.init();
    defer adapter.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        adapter.add_rating(line);
    }

    const one_by_three = adapter.get_one_by_three();

    const out = std.io.getStdOut().writer();
    try out.print("One * Three = {}\n", .{one_by_three});
}
