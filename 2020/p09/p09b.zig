const std = @import("std");
const ROM = @import("./rom.zig").ROM;

pub fn main() anyerror!void {
    var rom = ROM.init(25);
    defer rom.deinit();

    var bad: usize = 0;
    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        bad = rom.add_number(line);
        if (bad > 0) {
            break;
        }
    }
    const sum = rom.find_contiguous_sum(bad);

    const out = std.io.getStdOut().writer();
    try out.print("Sum: {}\n", .{sum});
}
