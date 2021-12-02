const std = @import("std");
const Food = @import("./food.zig").Food;

pub fn main() anyerror!void {
    var food = Food.init();
    defer food.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        food.add_line(line);
    }

    const count = food.count_without_allergens();

    const out = std.io.getStdOut().writer();
    try out.print("Count: {}\n", .{count});
}
