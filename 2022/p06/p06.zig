const std = @import("std");
const command = @import("./util/command.zig");
const Device = @import("./device.zig").Device;

pub fn main() anyerror!u8 {
    const part = command.choose_part();
    if (part <= 0 or part > 2) return 99;
    return try problem(part);
}

pub fn problem(part: u8) anyerror!u8 {
    var device = Device.init();

    const inp = std.io.getStdIn().reader();
    var buf: [10*1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try device.feed(line);
        const offset = if (part == 1) device.find_packet_marker() else device.find_message_marker();
        const out = std.io.getStdOut().writer();
        try out.print("Offset: {}\n", .{offset});
    }
    return 0;
}
