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

        // If we can jump again or walk forward one tile after jumping, then jump.
        // Solution2: ((!A || !B || !C) && D) && (H || E)
        //            (!(A && B && C) && D) && (H || E)
        //            Solution1 && (H || E)
        const code =
            \\OR A J
            \\AND B J
            \\AND C J
            \\NOT J J
            \\AND D J
            \\OR H T
            \\OR E T
            \\AND T J
            \\RUN
        ;
        const result = droid.run_code(code);
        try out.print("Damage reported: {}\n", result);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines\n", count);
}
