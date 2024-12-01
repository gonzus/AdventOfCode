const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Itinerary = struct {
    numL: std.ArrayList(usize),
    numR: std.ArrayList(usize),
    count: std.AutoHashMap(usize, usize),

    pub fn init(allocator: Allocator) Itinerary {
        const self = Itinerary{
            .numL = std.ArrayList(usize).init(allocator),
            .numR = std.ArrayList(usize).init(allocator),
            .count = std.AutoHashMap(usize, usize).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Itinerary) void {
        self.count.deinit();
        self.numR.deinit();
        self.numL.deinit();
    }

    pub fn addLine(self: *Itinerary, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ' ');

        const nl = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        try self.numL.append(nl);

        const nr = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        try self.numR.append(nr);
        const e = try self.count.getOrPutValue(nr, 0);
        e.value_ptr.* += 1;
    }

    pub fn getTotalDistance(self: *Itinerary) !usize {
        std.sort.heap(usize, self.numL.items, {}, std.sort.asc(usize));
        std.sort.heap(usize, self.numR.items, {}, std.sort.asc(usize));
        var total: usize = 0;
        for (self.numL.items, self.numR.items) |nl, nr| {
            // TODO: @abs
            if (nl < nr) {
                total += nr - nl;
            } else {
                total += nl - nr;
            }
        }
        return total;
    }

    pub fn getSimilarityScore(self: *Itinerary) !usize {
        var score: usize = 0;
        for (self.numL.items) |nl| {
            const count = self.count.get(nl) orelse continue;
            score += nl * count;
        }
        return score;
    }
};

test "sample part 1" {
    const data =
        \\3   4
        \\4   3
        \\2   5
        \\1   3
        \\3   9
        \\3   3
    ;

    var itinerary = Itinerary.init(std.testing.allocator);
    defer itinerary.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try itinerary.addLine(line);
    }

    const distance = itinerary.getTotalDistance();
    const expected = @as(usize, 11);
    try testing.expectEqual(expected, distance);
}

test "sample part 2" {
    const data =
        \\3   4
        \\4   3
        \\2   5
        \\1   3
        \\3   9
        \\3   3
    ;

    var itinerary = Itinerary.init(std.testing.allocator);
    defer itinerary.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try itinerary.addLine(line);
    }

    const score = itinerary.getSimilarityScore();
    const expected = @as(usize, 31);
    try testing.expectEqual(expected, score);
}
