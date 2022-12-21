const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Riddle = @import("./riddle.zig").Riddle;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var riddle = Riddle.init(allocator);
    defer riddle.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try riddle.add_line(line);
    }
    // riddle.show();

    var answer: isize = 0;
    if (part == 1) {
        const f = try riddle.solve_for_root();
        answer = @floatToInt(isize, f);
        const expected = @as(isize, 56490240862410);
        try testing.expectEqual(expected, answer);
    } else {
        const f = try riddle.search_for_human();
        answer = @floatToInt(isize, f);
        const expected = @as(isize, 3403989691757);
        try testing.expectEqual(expected, answer);
    }

    const out = std.io.getStdOut().writer();
    try out.print("Riddle: {}\n", .{answer});

    return 0;
}
