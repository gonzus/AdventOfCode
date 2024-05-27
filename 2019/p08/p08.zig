const std = @import("std");
const testing = std.testing;
const command = @import("./util/command.zig");
const Image = @import("./module.zig").Image;

pub fn main() anyerror!u8 {
    const part = command.choosePart();
    var image = Image.init(25, 6);

    const inp = std.io.getStdIn().reader();
    var buf: [20 * 1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        try image.addLine(line);
    }

    const out = std.io.getStdOut().writer();
    try out.print("=== {s} ===\n", .{@tagName(part)});
    switch (part) {
        .part1 => {
            const answer = try image.findLayerWithFewestBlackPixels();
            try out.print("Answer: {}\n", .{answer});
            const expected = @as(usize, 828);
            try testing.expectEqual(expected, answer);
        },
        .part2 => {
            const answer = try image.render();
            try out.print("Answer: {s}\n", .{answer});
            const expected = "ZLBJF";
            try testing.expectEqualStrings(expected, answer);
        },
    }

    try out.print("Elapsed: {}ms\n", .{command.getElapsedMs()});
    return 0;
}
