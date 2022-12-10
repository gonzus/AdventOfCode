const std = @import("std");
const command = @import("./util/command.zig");
const Cpu = @import("./cpu.zig").Cpu;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var cpu = Cpu.init(allocator);
    defer cpu.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try cpu.add_line(line);
    }

    const strength = cpu.run();
    const out = std.io.getStdOut().writer();
    if (part == 1) {
        try out.print("Strength: {}\n", .{strength});
    } else {
        try out.print("Letters:\n", .{});
        cpu.render_image();
    }
    return 0;
}
