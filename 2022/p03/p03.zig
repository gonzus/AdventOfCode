const std = @import("std");
const command = @import("./util/command.zig");
const Rucksack = @import("./rucksack.zig").Rucksack;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var rucksack = Rucksack.init(allocator);
    defer rucksack.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try rucksack.add_line(line);
    }

    const sum = if (part == 1) rucksack.get_compartment_total() else rucksack.get_group_total();
    const out = std.io.getStdOut().writer();
    try out.print("Sum of priorities: {}\n", .{sum});
    return 0;
}
