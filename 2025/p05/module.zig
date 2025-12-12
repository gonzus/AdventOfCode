const std = @import("std");
const testing = std.testing;

pub const Module = struct {
    const Range = struct {
        lo: usize,
        hi: usize,

        fn lessThan(_: void, l: Range, r: Range) bool {
            if (l.lo < r.lo) return true;
            if (l.lo > r.lo) return false;
            return (l.hi < r.hi);
        }
    };

    alloc: std.mem.Allocator,
    ranges: std.ArrayList(Range),
    fresh_count: usize,

    pub fn init(alloc: std.mem.Allocator) Module {
        return .{
            .alloc = alloc,
            .ranges = .{},
            .fresh_count = 0,
        };
    }

    pub fn deinit(self: *Module) void {
        self.ranges.deinit(self.alloc);
    }

    pub fn parseInput(self: *Module, data: []const u8) !void {
        var counting = false;
        var it_lines = std.mem.splitScalar(u8, data, '\n');
        while (it_lines.next()) |line| {
            if (line.len == 0) {
                std.debug.assert(self.ranges.items.len > 0);
                std.sort.heap(Range, self.ranges.items, {}, Range.lessThan);
                counting = true;
                continue;
            }

            if (counting) {
                const id = try std.fmt.parseUnsigned(usize, line, 10);
                for (self.ranges.items) |r| {
                    if (r.lo > id) break;
                    if (id <= r.hi) {
                        self.fresh_count += 1;
                        break;
                    }
                }
                continue;
            }

            var it = std.mem.tokenizeScalar(u8, line, '-');
            const r = Range{
                .lo = try std.fmt.parseUnsigned(usize, it.next().?, 10),
                .hi = try std.fmt.parseUnsigned(usize, it.next().?, 10),
            };
            std.debug.assert(r.lo <= r.hi);
            try self.ranges.append(self.alloc, r);
        }
    }

    pub fn countFreshIDs(self: Module) !usize {
        return self.fresh_count;
    }

    pub fn mergeAndCountIDs(self: Module) !usize {
        var merged: std.ArrayList(Range) = .{};
        defer merged.deinit(self.alloc);
        var prev = self.ranges.items[0];
        try merged.append(self.alloc, prev);
        for (1..self.ranges.items.len) |p| {
            const curr = self.ranges.items[p];
            if (curr.hi <= prev.hi) {
                // prev covers both intervals
                continue;
            }
            if (curr.lo <= prev.hi) {
                // intervals overlap
                prev.hi = curr.hi;
                _ = merged.pop();
                try merged.append(self.alloc, prev);
                continue;
            }
            {
                // intervals do not overlap
                try merged.append(self.alloc, curr);
                prev = curr;
                continue;
            }
        }

        var count: usize = 0;
        for (merged.items) |r| {
            const size = r.hi - r.lo + 1;
            count += size;
        }
        return count;
    }
};

test "sample part 1" {
    const data =
        \\3-5
        \\10-14
        \\16-20
        \\12-18
        \\
        \\1
        \\5
        \\8
        \\11
        \\17
        \\32
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();
    try module.parseInput(data);

    const fresh = try module.countFreshIDs();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, fresh);
}

test "sample part 2" {
    const data =
        \\3-5
        \\10-14
        \\16-20
        \\12-18
        \\
        \\1
        \\5
        \\8
        \\11
        \\17
        \\32
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();
    try module.parseInput(data);

    const fresh = try module.mergeAndCountIDs();
    const expected = @as(usize, 14);
    try testing.expectEqual(expected, fresh);
}
