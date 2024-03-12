const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Warehouse = @import("./module.zig").Warehouse;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var warehouse = Warehouse.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try warehouse.addLine(line);
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    switch (part) {
        .part1 => {
            const answer = warehouse.getChecksum();
            const expected = @as(usize, 6448);
            try testing.expectEqual(expected, answer);
            try out.print("Answer: {}\n", .{answer});
        },
        .part2 => {
            const answer = warehouse.getCommonLeters();
            const expected = "evsialkqyiurohzpwucngttmf";
            try testing.expectEqualStrings(expected, answer);
            try out.print("Answer: {s}\n", .{answer});
        },
    }

    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
