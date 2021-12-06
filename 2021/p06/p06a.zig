const std = @import("std");
const Fish = @import("./fish.zig").Fish;

pub fn main() anyerror!void {
    var fish = Fish.init();
    defer fish.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        fish.process_line(line);
    }

    const DAYS = 80;
    const count = fish.count_fish_after_n_days(DAYS);
    const out = std.io.getStdOut().writer();
    try out.print("Fish after {} days: {}\n", .{ DAYS, count });
}
