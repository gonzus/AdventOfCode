const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Bob = @import("./fuel.zig").Bob;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var bob = Bob.init(allocator);
    defer bob.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try bob.add_line(line);
    }
    // bob.show();

    const out = std.io.getStdOut().writer();
    if (part == 1) {
        const fuel = bob.total_fuel();
        const snafu = Bob.convert_10_to_5(fuel, &buf);
        const expected = "2=2-1-010==-0-1-=--2";
        try testing.expectEqualSlices(u8, expected, snafu);
        try out.print("SNAFU: {s}\n", .{snafu});
    } else {
        try out.print("Day 25 only had part 1\n", .{});
    }

    return 0;
}
