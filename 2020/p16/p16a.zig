const std = @import("std");
const DB = @import("./ticket.zig").DB;

pub fn main() anyerror!void {
    var db = DB.init();
    defer db.deinit();

    const inp = std.io.getStdIn().reader();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        db.add_line(line);
    }

    const tser = db.ticket_scanning_error_rate();

    const out = std.io.getStdOut().writer();
    try out.print("Ticket scanning error rate: {}\n", .{tser});
}
