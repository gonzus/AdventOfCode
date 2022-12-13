const std = @import("std");
const command = @import("./util/command.zig");
const Signal = @import("./signal.zig").Signal;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var signal = try Signal.init(allocator);
    defer signal.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try signal.add_line(line);
    }

    const sum = if (part == 1) signal.sum_indices_in_right_order() else try signal.get_decoder_key();
    const out = std.io.getStdOut().writer();
    try out.print("{s}: {}\n", .{if (part == 1) "Sum of indices" else "Decoder key", sum});
    return 0;
}
