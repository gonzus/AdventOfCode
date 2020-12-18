const std = @import("std");
const Evaluator = @import("./evaluator.zig").Evaluator;

pub fn main() anyerror!void {
    var evaluator = Evaluator.init(Evaluator.Precedence.None);
    defer evaluator.deinit();

    var sum: usize = 0;
    const inp = std.io.bufferedInStream(std.io.getStdIn().inStream()).inStream();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        sum += evaluator.eval(line);
    }

    const out = std.io.getStdOut().outStream();
    try out.print("Sum: {}\n", .{sum});
}
