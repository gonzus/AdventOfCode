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

    var cave = Cave.init(allocator);
    defer cave.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try cave.add_line(line);
    }
    // cave.show();

    const out = std.io.getStdOut().writer();
    if (part == 1) {
        const row = 2000000;
        const count = try cave.count_empty_spots_in_row(row);
        try out.print("Empty count for row {}: {}\n", .{row, count});
    } else {
        const top = 4000000;
        const frequency = try cave.find_distress_beacon_frequency(0, top);
        try out.print("Tuning frequency up to {}: {}\n", .{top, frequency});
    }
    return 0;
}
