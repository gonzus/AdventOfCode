const std = @import("std");
const FFT = @import("./fft.zig").FFT;
const allocator = std.testing.allocator;

pub fn main() !void {
    const out = std.io.getStdOut().writer();
    const inp = std.io.getStdIn().reader();
    var buf: [20480]u8 = undefined;
    var count: u32 = 0;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        count += 1;

        var fft = FFT.init();
        defer fft.deinit();

        var output: []u8 = allocator.alloc(u8, line.len) catch @panic("FUCK\n");
        defer allocator.free(output);

        fft.parse(line, 1);
        fft.run_phases(100, output[0..], line.len);
        // Your puzzle answer was 37153056.
        std.debug.warn("First 8 characters of output: ", .{});
        var j: usize = 0;
        while (j < 8) : (j += 1) {
            std.debug.warn("{}", .{output[j]});
        }
        std.debug.warn("\n", .{});
    }
    try out.print("Read {} lines\n", .{count});
}
