const std = @import("std");

pub fn choose_part() u8 {
    var args = std.process.args();
    // skip my own exe name
    _ = args.skip();
    var part: u8 = 0;
    while (args.next()) |arg| {
        part = std.fmt.parseInt(u8, arg, 10) catch 0;
        break;
    }
    if (part <= 0 or part > 2) return 0;

    std.debug.print("--- Part {} ---\n", .{part});
    return part;
}
