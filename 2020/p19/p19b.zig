const std = @import("std");
const Validator = @import("./validator.zig").Validator;

pub fn main() anyerror!void {
    var validator = Validator.init();
    defer validator.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        validator.add_line(line);
    }

    validator.fixup_rules();
    const count = validator.count_valid();

    const out = std.io.getStdOut().writer();
    try out.print("Count: {}\n", .{count});
}
