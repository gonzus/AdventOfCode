const std = @import("std");
const FFT = @import("./fft.zig").FFT;

pub fn main() !void {
    const stdout = std.io.getStdOut() catch unreachable;
    const out = &stdout.outStream().stream;

    const allocator = std.debug.global_allocator;
    var buf = try std.Buffer.initSize(allocator, 0);

    var count: u32 = 0;
    while (std.io.readLine(&buf)) |line| {
        count += 1;

        var fft = FFT.init();
        defer fft.deinit();

        var output: []u8 = allocator.alloc(u8, line.len) catch @panic("FUCK\n");
        defer allocator.free(output);

        fft.parse(line, 1);
        fft.run_phases(100, output[0..], line.len);
        // Your puzzle answer was 37153056.
        std.debug.warn("First 8 characters of output: ");
        var j: usize = 0;
        while (j < 8) : (j += 1) {
            std.debug.warn("{}", output[j]);
        }
        std.debug.warn("\n");
    } else |err| {
        // try out.print("Error, {}!\n", err);
    }
    try out.print("Read {} lines\n", count);
}
