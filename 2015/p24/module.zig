const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Sleigh = struct {
    allocator: Allocator,
    packages: std.ArrayList(usize),
    total: usize,
    used: u32,
    smallest: usize,
    best: usize,

    pub fn init(allocator: Allocator) Sleigh {
        return Sleigh{
            .allocator = allocator,
            .packages = std.ArrayList(usize).init(allocator),
            .total = 0,
            .used = 0,
            .smallest = std.math.maxInt(usize),
            .best = std.math.maxInt(usize),
        };
    }

    pub fn deinit(self: *Sleigh) void {
        self.packages.deinit();
    }

    pub fn addLine(self: *Sleigh, line: []const u8) !void {
        const w = try std.fmt.parseUnsigned(u8, line, 10);
        try self.packages.append(w);
        self.total += w;
    }

    pub fn show(self: Sleigh) void {
        std.debug.print("Sleigh with {} packages, {} total weight:\n", .{ self.packages.items.len, self.total });
        for (self.packages.items) |p| {
            std.debug.print("  {}\n", .{p});
        }
    }

    pub fn findSmallestEntanglement(self: *Sleigh, compartments: usize) usize {
        const weight: usize = self.total / compartments;
        self.used = 0;
        self.walkCombinations(true, weight);
        self.used = 0;
        self.walkCombinations(false, weight);
        return self.best;
    }

    fn walkCombinations(self: *Sleigh, searching_size: bool, left: usize) void {
        const count = self.countUsed();
        if (left == 0) {
            if (searching_size) {
                self.smallest = @min(self.smallest, count);
            } else if (count == self.smallest) {
                self.best = @min(self.best, self.getEntanglement());
            }
            return;
        }
        if (count > self.smallest) return;

        var mask: u32 = 1;
        for (self.packages.items) |package| {
            if (package > left) continue;
            if (self.used & mask > 0) continue;
            self.used |= mask;
            self.walkCombinations(searching_size, left - package);
            self.used &= ~mask;
            mask <<= 1;
        }
    }

    fn countUsed(self: Sleigh) usize {
        var count: usize = 0;
        var mask: u32 = 1;
        var pos: usize = 0;
        while (pos < 32) : (pos += 1) {
            if (self.used & mask > 0) {
                count += 1;
            }
            mask <<= 1;
        }
        return count;
    }

    fn getEntanglement(self: Sleigh) usize {
        var entanglement: usize = 1;
        var mask: u32 = 1;
        var pos: usize = 0;
        while (pos < 32) : (pos += 1) {
            if (self.used & mask > 0) {
                entanglement *= self.packages.items[pos];
            }
            mask <<= 1;
        }
        return entanglement;
    }
};

test "sample part 1" {
    const data =
        \\1
        \\2
        \\3
        \\4
        \\5
        \\7
        \\8
        \\9
        \\10
        \\11
    ;

    var sleigh = Sleigh.init(std.testing.allocator);
    defer sleigh.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try sleigh.addLine(line);
    }
    // sleigh.show();

    const entanglement = sleigh.findSmallestEntanglement(3);
    const expected = @as(usize, 99);
    try testing.expectEqual(expected, entanglement);
}

test "sample part 2" {
    const data =
        \\1
        \\2
        \\3
        \\4
        \\5
        \\7
        \\8
        \\9
        \\10
        \\11
    ;

    var sleigh = Sleigh.init(std.testing.allocator);
    defer sleigh.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try sleigh.addLine(line);
    }
    // sleigh.show();

    const entanglement = sleigh.findSmallestEntanglement(4);
    const expected = @as(usize, 44);
    try testing.expectEqual(expected, entanglement);
}
