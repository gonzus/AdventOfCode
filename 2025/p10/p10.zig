const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Module = @import("./module.zig").Module;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const part = command.choosePart();
    var module = Module.init(arena.allocator());
    defer module.deinit();

    const SIZE = 18 * 1024;

    var stdin_buffer: [SIZE]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    var stdout_buffer: [SIZE]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    read: while (true) {
        const line = stdin.takeDelimiterInclusive('\n') catch |err| {
            if (err == error.EndOfStream) break :read;
            return err;
        };
        try module.addLine(std.mem.trim(u8, line, "\r\n"));
    }

    var answer: i16 = 0;
    switch (part) {
        .part1 => {
            answer = try module.getTotalButtonPressesForLights();
            const expected = @as(i16, 436);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try module.getTotalButtonPressesForJoltages();
            const expected = @as(i16, 14999);
            try testing.expectEqual(expected, answer);
        },
    }

    try stdout.print("--- {s} ---\n", .{@tagName(part)});
    try stdout.print("Answer: {}\n", .{answer});
    try stdout.print("Elapsed: {}us\n", .{command.getElapsedUs()});
    try stdout.flush();
    return 0;
}
