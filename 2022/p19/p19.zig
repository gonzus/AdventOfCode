const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Factory = @import("./factory.zig").Factory;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var factory = Factory.init(allocator);
    defer factory.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try factory.add_line(line);
    }
    // factory.show();

    const out = std.io.getStdOut().writer();
    if (part == 1) {
        const sql = try factory.sum_quality_levels(24);
        const expected = @as(usize, 600);
        try testing.expectEqual(expected, sql);
        try out.print("Sum of quality levels: {}\n", .{sql});
    } else  {
        const count = 3;
        const product = try factory.multiply_geodes(32, count);
        const expected = @as(usize, 6000);
        try testing.expectEqual(expected, product);
        try out.print("Product of first {} max geodes: {}\n", .{count, product});
    }

    return 0;
}
