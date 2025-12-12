const std = @import("std");
const Command = @import("./util/command.zig").Command;
const Module = @import("./module.zig").Module;

pub fn main() anyerror!u8 {
    var command = try Command.init();
    defer command.deinit();

    const part = command.choosePart();
    var answer: usize = 2025;
    switch (part) {
        .part1 => {
            var module = Module.init(command.allocator());
            defer module.deinit();

            try module.parseInput(try command.readInput());
            // module.show();

            answer = try module.countViableRegions();
            const expected = @as(usize, 524);
            try std.testing.expectEqual(expected, answer);
        },
        .part2 => {},
    }

    try command.showResults(part, answer);
    return 0;
}
