const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Computer = @import("./module.zig").Computer;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var computer = Computer.init(allocator);
    defer computer.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try computer.addLine(line);
    }
    // computer.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            try computer.run();
            answer = computer.getRegister(.b);
            const expected = @as(usize, 307);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            computer.setRegister(.a, 1);
            try computer.run();
            answer = computer.getRegister(.b);
            const expected = @as(usize, 160);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
