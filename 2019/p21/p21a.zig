const std = @import("std");
const Droid = @import("./droid.zig").Droid;

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [20480]u8 = undefined;
    var count: u32 = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
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
        try out.print("Damage reported: {}\n", .{result});
    }
    try out.print("Read {} lines\n", .{count});
}
