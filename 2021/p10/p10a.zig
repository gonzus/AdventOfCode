const std = @import("std");
const Navigation = @import("./navigation.zig").Navigation;

pub fn main() anyerror!void {
    var navigation = Navigation.init();
    defer navigation.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try navigation.process_line(line);
    }

    const syntax_error_score = navigation.get_syntax_error_score();
    const out = std.io.getStdOut().writer();
    try out.print("Total syntax error score: {}\n", .{syntax_error_score});
}
