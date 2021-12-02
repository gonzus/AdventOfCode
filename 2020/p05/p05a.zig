const std = @import("std");
const Passport = @import("./passport.zig").Passport;

pub fn main() anyerror!void {
    var passport = Passport.init();
    defer passport.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    var top: usize = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const id = passport.parse(line);
        if (top < id) {
            top = id;
        }
    }

    const out = std.io.getStdOut().writer();
    try out.print("Top passport id: {}\n", .{top});
}
