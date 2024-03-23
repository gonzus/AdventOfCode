const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const License = @import("./module.zig").License;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var license = License.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [50 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try license.addLine(line);
    }
    // license.show();

    var answer: usize = undefined;
    switch (part) {
        .part1 => {
            answer = license.sumMetadata();
            const expected = @as(usize, 46096);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = license.rootValue();
            const expected = @as(usize, 24820);
            try testing.expectEqual(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("Answer: {}\n", .{answer});
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
