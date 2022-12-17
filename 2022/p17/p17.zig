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

    var cave = try Cave.init(allocator);
    defer cave.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try cave.add_line(line);
    }
    // cave.show();

    const out = std.io.getStdOut().writer();
    const cycles: usize = if (part == 1) 2022 else 1000000000000;
    const height = try cave.run_cycles(cycles);
    try out.print("Height after {} cycles: {}\n", .{cycles, height});
    return 0;
}
