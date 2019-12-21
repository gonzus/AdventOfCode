const std = @import("std");
const Droid = @import("./droid.zig").Droid;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;

        var droid = Droid.init(line);
        defer droid.deinit();

        // If we have a hole one, two or three tiles away, and the fourth tile is not a hole, then jump.
        // Solution1: (!A || !B || !C) && D
        //            !(A && B && C) && D
        //
        const code =
            \\OR A J
            \\AND B J
            \\AND C J
            \\NOT J J
            \\AND D J
            \\WALK
        ;
        const result = droid.run_code(code);
        try out.print("Damage reported: {}\n", result);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines\n", count);
}
