const std = @import("std");
const command = @import("./util/command.zig");
const Food = @import("./food.zig").Food;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
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

    var count: usize = if (part == 1) 1 else 3;
    const top = food.get_top(count);
    const out = std.io.getStdOut().writer();
    try out.print("Total calories for top {} elves: {}\n", .{ count, top });
    return 0;
}
