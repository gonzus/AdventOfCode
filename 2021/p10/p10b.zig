const std = @import("std");
const Navigation = @import("./navigation.zig").Navigation;

pub fn main() !void {
    var navigation = Navigation.init();
    defer navigation.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try navigation.process_line(line);
    }

    const middle_score = navigation.get_completion_middle_score();
    const out = std.io.getStdOut().writer();
    try out.print("Middle score: {}\n", .{middle_score});
}
