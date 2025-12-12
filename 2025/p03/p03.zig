const std = @import("std");
const Command = @import("./util/command.zig").Command;
const Module = @import("./module.zig").Module;

pub fn main() anyerror!u8 {
    var command = try Command.init();
    defer command.deinit();

    const part = command.choosePart();
    var module = Module.init(command.allocator(), if (part == .part1) 2 else 12);
    defer module.deinit();

    try module.parseInput(try command.readInput());
    // module.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try module.getTotalJoltage();
            const expected = @as(usize, 17092);
            try std.testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try module.getTotalJoltage();
            const expected = @as(usize, 170147128753455);
            try std.testing.expectEqual(expected, answer);
        },
    }

    try command.showResults(part, answer);
    return 0;
}
