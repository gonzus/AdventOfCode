const std = @import("std");
const allocator = std.testing.allocator;
const Burrow = @import("./burrow.zig").Burrow;

pub fn main() anyerror!void {
    var burrow = Burrow.init();
    defer burrow.deinit();

    const data = try std.fs.cwd().readFileAlloc(allocator, "../data/input23.txt", 1024 * 1024);
    defer allocator.free(data);
    burrow.parse_data(data);

    const cost = try burrow.find_cheapest_solution();
    const out = std.io.getStdOut().writer();
    try out.print("Minimal cost: {}\n", .{cost});
}
