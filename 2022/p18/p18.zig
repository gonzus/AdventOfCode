const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Lava = @import("./lava.zig").Lava;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var lava = Lava.init(allocator);
    defer lava.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [10240]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try lava.add_line(line);
    }
    // lava.show();

    const area = try if (part == 1) lava.surface_area_total() else lava.surface_area_external();
    const expected = @as(usize, if (part == 1) 4500 else 2558);
    try testing.expectEqual(expected, area);

    const out = std.io.getStdOut().writer();
    try out.print("Surface area: {}\n", .{area});
    return 0;
}
