const std = @import("std");
const Vent = @import("./vent.zig").Vent;

pub fn main() anyerror!void {
    var vent = Vent.init(Vent.Mode.HorVerDiag);
    defer vent.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        vent.process_line(line);
    }

    const WANTED = 2;
    const points = vent.count_points_with_n_vents(WANTED);
    const out = std.io.getStdOut().writer();
    try out.print("Points with {} or more lines: {}\n", .{ WANTED, points });
}
