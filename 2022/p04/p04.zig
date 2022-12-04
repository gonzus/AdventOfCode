const std = @import("std");
const command = @import("./util/command.zig");
const Assignment = @import("./assignment.zig").Assignment;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var assignment = Assignment.init(allocator);
    defer assignment.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try assignment.add_line(line);
    }

    const count = if (part == 1) assignment.count_contained() else assignment.count_overlapping();
    const out = std.io.getStdOut().writer();
    try out.print("Interesting groups: {}\n", .{count});
    return 0;
}
