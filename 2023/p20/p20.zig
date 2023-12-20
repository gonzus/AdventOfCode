const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Circuit = @import("./island.zig").Circuit;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var circuit = Circuit.init(allocator);
    defer circuit.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try circuit.addLine(line);
    }
    // circuit.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try circuit.getPulseProduct(1000);
            const expected = @as(usize, 899848294);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try circuit.pressUntilModuleActivates();
            const expected = @as(usize, 247454898168563);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
