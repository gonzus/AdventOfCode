const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Disk = @import("./module.zig").Disk;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var disk = Disk.init(allocator);

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try disk.addLine(line);
    }

    var answer: []const u8 = undefined;
    switch (part) {
        .part1 => {
            answer = try disk.getDiskChecksum(272, &buf);
            const expected = "10111110010110110";
            try testing.expectEqualSlices(u8, expected, answer);
        },
        .part2 => {
            answer = try disk.getDiskChecksum(35651584, &buf);
            const expected = "01101100001100100";
            try testing.expectEqualSlices(u8, expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {s}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
