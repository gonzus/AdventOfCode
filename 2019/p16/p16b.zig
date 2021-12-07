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

        var output: []u8 = allocator.alloc(u8, line.len * 10000) catch @panic("FUCK\n");
        defer allocator.free(output);

        const offset: usize = 5970221;
        fft.parse(line, 10000);
        fft.run_phases(100, output[0..], 10000 * line.len - offset);
        std.debug.warn("First 8 characters of output after offset {}: ", .{offset});
        var j: usize = 0;
        while (j < 8) : (j += 1) {
            std.debug.warn("{}", .{output[j + offset]});
        }
        std.debug.warn("\n", .{});
    }
    try out.print("Read {} lines\n", .{count});
}
