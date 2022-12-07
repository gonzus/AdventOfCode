const std = @import("std");
const command = @import("./util/command.zig");
const Tree = @import("./tree.zig").Tree;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var tree = Tree.init(allocator);
    defer tree.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try tree.add_line(line);
    }

    const size = if (part == 1) tree.add_dirs_at_most(100_000) else tree.smallest_dir_to_achieve(70_000_000, 30_000_000);
    const out = std.io.getStdOut().writer();
    try out.print("Size: {}\n", .{size});
    return 0;
}
