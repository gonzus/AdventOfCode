const std = @import("std");
const Network = @import("./network.zig").Network;

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var count: u32 = 0;
    var buf: [20480]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;

        var network = Network.init(line);
        defer network.deinit();
        const result = network.run(true);
        try out.print("Output reported: {}\n", .{result});
    }
    try out.print("Read {} lines\n", .{count});
}
