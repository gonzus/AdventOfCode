const std = @import("std");
const Passport = @import("./passport.zig").Passport;

pub fn main() anyerror!void {
    var passport = Passport.init();
    defer passport.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        _ = passport.parse(line);
    }

    const id = passport.find_missing();

    const out = std.io.getStdOut().writer();
    try out.print("Missing passport id: {}\n", .{id});
}
