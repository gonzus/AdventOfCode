const std = @import("std");
const Crypto = @import("./crypto.zig").Crypto;

pub fn main() anyerror!void {
    var crypto = Crypto.init();
    defer crypto.deinit();

    const inp = std.io.bufferedInStream(std.io.getStdIn().inStream()).inStream();
    var buf: [1024]u8 = undefined;
    while (try inp.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        crypto.add_public_key(line);
    }

    const encryption_key = crypto.guess_encryption_key();

    const out = std.io.getStdOut().outStream();
    try out.print("Encryption key: {}\n", .{encryption_key});
}
