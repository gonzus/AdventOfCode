const std = @import("std");

const Part = enum { part1, part2 };

var timer: std.time.Timer = undefined;

pub fn choosePart() Part {
    var args = std.process.args();
    // skip my own exe name
    _ = args.skip();
    var part: u8 = 0;
    while (args.next()) |arg| {
        part = std.fmt.parseInt(u8, arg, 10) catch 0;
        break;
    }
    timer = std.time.Timer.start() catch unreachable;
    return switch (part) {
        1 => .part1,
        2 => .part2,
        else => @panic("Invalid part"),
    };
}

pub fn getElapsedMs() u64 {
    return timer.read() / std.time.ns_per_ms;
}
