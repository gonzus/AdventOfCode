const std = @import("std");
const Command = @import("./util/command.zig").Command;
const Module = @import("./module.zig").Module;

pub fn main() anyerror!u8 {
    var command = try Command.init();
    defer command.deinit();

    const part = command.choosePart();
    var module = Module.init(command.allocator(), part == .part2);
    defer module.deinit();

    try module.parseInput(try command.readInput());
    // module.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try module.getSumInvalidIds();
            const expected = @as(usize, 12586854255);
            try std.testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try module.getSumInvalidIds();
            const expected = @as(usize, 17298174201);
            try std.testing.expectEqual(expected, answer);
        },
    }

    try command.showResults(part, answer);
    return 0;
}
