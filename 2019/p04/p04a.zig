const std = @import("std");
const Sleuth = @import("./sleuth.zig").Sleuth;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var sleuth = Sleuth.init();

    while (std.io.readLine(&buf)) |line| {
        try sleuth.search(line, match);

        try out.print("Found {} matches between {} and {}\n", sleuth.count, sleuth.lo, sleuth.hi);
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
}

fn match(n: i32) bool {
    // try out.print("GONZO {}\n", n);
    var rep: usize = 0;
    var dec: usize = 0;
    var m: i32 = n;
    var q: i8 = 99;
    while (m > 0 and dec == 0) {
        var d: i8 = @intCast(i8, @mod(@intCast(i32, m), 10));
        m = @divFloor(m, 10);
        if (d > q) {
            dec += 1;
            break;
        }
        if (d == q) {
            rep += 1;
        }
        q = d;
    }
    if (rep == 0 or dec > 0) {
        return false;
    }
    // try out.print("FOUND {}\n", n);
    return true;
}
