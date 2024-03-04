const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Building = @import("./module.zig").Building;

pub fn main() anyerror!u8 {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const part = command.choosePart();
    var building = try Building.init(allocator, part == .part2);
    defer building.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try building.addLine(line);
    }

    var answer: []const u8 = "";
    switch (part) {
        .part1 => {
            answer = try building.getCode();
            const expected = "52981";
            try testing.expectEqualStrings(expected, answer);
        },
        .part2 => {
            answer = try building.getCode();
            const expected = "74CD2";
            try testing.expectEqualStrings(expected, answer);
        },
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    try out.print("Answer: {s}\n", .{answer});
    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
