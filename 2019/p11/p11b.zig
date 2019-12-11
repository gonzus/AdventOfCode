const std = @import("std");
const Ship = @import("./ship.zig").Ship;
const Computer = @import("./computer.zig").Computer;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;

        var ship = Ship.init(Ship.Color.White);
        defer ship.deinit();

        var computer = Computer.init(true);
        defer computer.deinit();

        computer.parse(line);
        while (!computer.halted) {
            const color = ship.scan_color();
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
                    const next_color = @intToEnum(Ship.Color, @intCast(u8, output.?));
                    // std.debug.warn("SHIP painting {}\n", next_color);
                    ship.paint_color(next_color);
                } else {
                    const next_rotation = @intToEnum(Ship.Rotation, @intCast(u8, output.?));
                    // std.debug.warn("SHIP rotating {}\n", next_rotation);
                    ship.move(next_rotation);
                }
            }
        }

        try out.print("Line {}, painted {} cells\n", count, ship.painted);
        try out.print("Bounds: {} {} - {} {}\n", ship.ix, ship.iy, ship.ax, ship.ay);
        var y: usize = ship.ay;
        while (y >= ship.iy) : (y -= 1) {
            var x: usize = ship.ix;
            while (x <= ship.ax) : (x += 1) {
                const color = ship.get_color(x, y);
                switch (color) {
                    Ship.Color.Black => try out.print(" "),
                    Ship.Color.White => try out.print("\u{2588}"),
                }
            }
            try out.print("\n");
        }
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines\n", count);
}
