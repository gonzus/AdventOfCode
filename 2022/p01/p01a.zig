const std = @import("std");
const Food = @import("./food.zig").Food;

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var food = Food.init(allocator);
    defer food.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try food.add_line(line);
    }

    const count = 1;
    const top = food.get_top(count);
    const out = std.io.getStdOut().writer();
    try out.print("Total calories for top {} elves: {}\n", .{count, top});
}
