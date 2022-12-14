const std = @import("std");
const command = @import("./util/command.zig");
const Cave = @import("./cave.zig").Cave;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const with_floor = part == 2;
    var cave = try Cave.init(allocator, with_floor);
    defer cave.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try cave.add_line(line);
    }

    const count = try cave.drop_sand_until_stable();
    const out = std.io.getStdOut().writer();
    try out.print("Count: {}\n", .{count});
    return 0;
}
