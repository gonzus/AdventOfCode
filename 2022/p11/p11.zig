const std = @import("std");
const command = @import("./util/command.zig");
const Troop = @import("./troop.zig").Troop;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var troop = Troop.init(allocator, if (part == 1) 3 else 1);
    defer troop.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try troop.add_line(line);
    }

    try troop.run_for_rounds(if (part == 1) 20 else 10_000);
    const mb = try troop.monkey_business();
    const out = std.io.getStdOut().writer();
    try out.print("Monkey business: {}\n", .{mb});
    return 0;
}
