const std = @import("std");
const Checksum = @import("./checksum.zig").Checksum;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var checksum = Checksum.init();
    defer checksum.deinit();

    while (std.io.readLine(&buf)) |line| {
        checksum.add_word(line);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    var common: [26]u8 = undefined;
    const len = checksum.find_common_letters(&common);
    try out.print("Common letters: {}\n", common[0..len]);
}
