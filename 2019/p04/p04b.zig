const std = @import("std");
const Tank = @import("./tank.zig").Tank;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const lo: i32 = 168630;
    const hi: i32 = 718098;

    var n: i32 = lo;
    while (n <= hi) : (n += 1) {
        // try out.print("GONZO {}\n", n);
        var rep: [10]usize = undefined;
        var j: usize = 0;
        while (j < 10) : (j += 1) {
            rep[j] = 0;
        }
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
                rep[@intCast(usize, d)] += 1;
            }
            q = d;
        }
        if (dec > 0) {
            continue;
        }
        var c2: usize = 0;
        var cm: usize = 0;
        j = 0;
        while (j < 10) : (j += 1) {
            if (rep[j] < 1) {
                continue;
            }
            if (rep[j] == 1) {
                c2 += 1;
            } else {
                cm += 1;
            }
        }
        if (c2 == 0) {
            continue;
        }
        try out.print("FOUND {}\n", n);
    }
}
