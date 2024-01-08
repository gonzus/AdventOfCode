const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Refrigerator = struct {
    const INVALID_SIZE = std.math.maxInt(usize);

    containers: std.ArrayList(usize),
    containers_smallest: usize,
    containers_wanted: usize,

    pub fn init(allocator: Allocator) Refrigerator {
        return Refrigerator{
            .containers = std.ArrayList(usize).init(allocator),
            .containers_smallest = INVALID_SIZE,
            .containers_wanted = INVALID_SIZE,
        };
    }

    pub fn deinit(self: *Refrigerator) void {
        self.containers.deinit();
    }

    pub fn addLine(self: *Refrigerator, line: []const u8) !void {
        const container = try std.fmt.parseUnsigned(usize, line, 10);
        try self.containers.append(container);
    }

    pub fn countTotalCombinations(self: *Refrigerator, volume: usize) !usize {
        return self.walkCombinations(volume, 0, 0);
    }

    pub fn countSmallestCombinations(self: *Refrigerator, volume: usize) !usize {
        if (self.containers_smallest == INVALID_SIZE) {
            _ = self.walkCombinations(volume, 0, 0);
        }
        self.containers_wanted = self.containers_smallest;
        return self.walkCombinations(volume, 0, 0);
    }

    fn walkCombinations(self: *Refrigerator, volume_left: usize, containers_used: usize, pos: usize) usize {
        if (volume_left == 0) { // found a solution
            if (self.containers_wanted == INVALID_SIZE) {
                // we are counting all solutions and looking for smallest
                self.containers_smallest = @min(self.containers_smallest, containers_used);
                return 1;
            }
            if (containers_used == self.containers_wanted) {
                // we are only counting containers_used == containers_wanted
                return 1;
            }
            return 0; // we don't care about this solution
        }

        if (pos >= self.containers.items.len) return 0; // no containers left

        var count: usize = 0;
        if (volume_left >= self.containers.items[pos]) {
            // current container is not too big, try to use it
            count += self.walkCombinations(volume_left - self.containers.items[pos], containers_used + 1, pos + 1);
        }
        // try skipping current countainter
        count += self.walkCombinations(volume_left, containers_used, pos + 1);
        return count;
    }
};

test "sample part 1" {
    const data =
        \\20
        \\15
        \\10
        \\5
        \\5
    ;

    var refrigerator = Refrigerator.init(std.testing.allocator);
    defer refrigerator.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try refrigerator.addLine(line);
    }

    const combinations = try refrigerator.countTotalCombinations(25);
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, combinations);
}

test "sample part 2" {
    const data =
        \\20
        \\15
        \\10
        \\5
        \\5
    ;

    var refrigerator = Refrigerator.init(std.testing.allocator);
    defer refrigerator.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try refrigerator.addLine(line);
    }

    const combinations = try refrigerator.countSmallestCombinations(25);
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, combinations);
}
