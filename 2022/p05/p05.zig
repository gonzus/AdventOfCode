const std = @import("std");
const command = @import("./util/command.zig");
const Arrangement = @import("./crates.zig").Arrangement;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var arrangement = Arrangement.init(allocator);
    defer arrangement.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try arrangement.add_line(line);
    }

    try arrangement.rearrange(part == 2);
    const message = try arrangement.get_message();
    const out = std.io.getStdOut().writer();
    try out.print("Message: {s}\n", .{message});
    return 0;
}
