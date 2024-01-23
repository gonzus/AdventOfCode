const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Address = @import("./module.zig").Address;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var address = Address.init(allocator);
    defer address.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try address.addLine(line);
    }

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = address.getAddressesSupportingTLS();
            const expected = @as(usize, 118);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = address.getAddressesSupportingSSL();
            const expected = @as(usize, 260);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
