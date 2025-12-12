const std = @import("std");
const Command = @import("./util/command.zig").Command;
const Module = @import("./module.zig").Module;

pub fn main() anyerror!u8 {
    var command = try Command.init();
    defer command.deinit();

    const part = command.choosePart();
    var module = Module.init();
    defer module.deinit();

    try module.parseInput(try command.readInput());
    // module.show();

    var answer: usize = 0;
    switch (part) {
        .part1 => {
            answer = try module.countBeamSplits();
            const expected = @as(usize, 1698);
            try std.testing.expectEqual(expected, answer);
        },
        .part2 => {
            answer = try module.countQuantumTimelines();
            const expected = @as(usize, 95408386769474);
            try std.testing.expectEqual(expected, answer);
        },
    }

    try command.showResults(part, answer);
    return 0;
}
