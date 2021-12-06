const std = @import("std");
const ship = @import("./ship.zig");
const Hull = ship.Hull;
const Computer = @import("./computer.zig").Computer;

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [20480]u8 = undefined;
    var count: u32 = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;

        var hull = Hull.init(Hull.Color.Black);
        defer hull.deinit();

        var computer = Computer.init(true);
        defer computer.deinit();

        computer.parse(line);
        while (!computer.halted) {
            const color = hull.get_current_color();
            const input = @enumToInt(color);
            // std.debug.warn("SHIP enqueuing {}\n", color);
            computer.enqueueInput(input);
            computer.run();
            var state: usize = 0;
            while (state < 2) : (state += 1) {
                const output = computer.getOutput();
                if (output == null) {
                    if (computer.halted) break;
                } else if (state == 0) {
                    const next_color = @intToEnum(Hull.Color, @intCast(u8, output.?));
                    // std.debug.warn("SHIP painting {}\n", next_color);
                    hull.paint(next_color);
                } else {
                    const next_rotation = @intToEnum(Hull.Rotation, @intCast(u8, output.?));
                    // std.debug.warn("SHIP rotating {}\n", next_rotation);
                    hull.move(next_rotation);
                }
            }
        }

        try out.print("Line {}, painted {} cells\n", .{ count, hull.painted });
    }
    try out.print("Read {} lines\n", .{count});
}
