const std = @import("std");
const command = @import("./util/command.zig");
const Forest = @import("./forest.zig").Forest;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var forest = Forest.init();
    defer forest.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try forest.add_line(line);
    }

    const value = if (part == 1) forest.count_visible() else forest.find_most_scenic();
    const out = std.io.getStdOut().writer();
    try out.print("{s}: {}\n", .{if (part == 1) "Visible" else "Score", value});
    return 0;
}
