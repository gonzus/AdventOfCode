const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Reactor = struct {
    const Report = struct {
        levels: std.ArrayList(isize),
        pub fn init(allocator: Allocator) Report {
            const self = Report{
                .levels = std.ArrayList(isize).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Report) void {
            self.levels.deinit();
        }

        pub fn addLevel(self: *Report, level: isize) !void {
            try self.levels.append(level);
        }

        pub fn isSafe(self: Report, dampener: bool) !bool {
            if (!dampener) {
                return try checkSafety(self, std.math.maxInt(usize));
            }
            for (0..self.levels.items.len) |skip| {
                if (try checkSafety(self, skip)) {
                    return true;
                }
            }
            return false;
        }

        fn checkSafety(self: Report, skip: usize) !bool {
            if (self.levels.items.len <= 1) return true; // only one element => safe
            const Dir = enum { undefined, ascending, descending };
            var dir = Dir.undefined;
            var last: isize = std.math.maxInt(isize);
            for (self.levels.items, 0..) |num, pos| {
                if (pos == skip) continue; // skip dampened, if any
                if (last == std.math.maxInt(isize)) { // first number
                    last = num; // remember last number
                    continue;
                }
                if (last == num) return false; // consecutive identical numbers
                switch (dir) {
                    .undefined => dir = if (last > num) .descending else .ascending, // remember direction
                    .ascending => if (num < last) return false, // check for ascending
                    .descending => if (num > last) return false, // check for descending
                }
                const delta = @abs(num - last);
                if (delta < 1 or delta > 3) return false; // check for difference
                last = num; // remember last number
            }
            return true; // found no problems
        }
    };

    allocator: Allocator,
    dampener: bool,
    reports: std.ArrayList(Report),

    pub fn init(allocator: Allocator, dampener: bool) Reactor {
        const self = Reactor{
            .allocator = allocator,
            .dampener = dampener,
            .reports = std.ArrayList(Report).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Reactor) void {
        for (self.reports.items) |*r| {
            r.*.deinit();
        }
        self.reports.deinit();
    }

    pub fn addLine(self: *Reactor, line: []const u8) !void {
        var report = Report.init(self.allocator);
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        while (it.next()) |chunk| {
            const level = try std.fmt.parseUnsigned(isize, chunk, 10);
            try report.addLevel(level);
        }
        try self.reports.append(report);
    }

    pub fn countSafeReports(self: Reactor) !usize {
        var count: usize = 0;
        for (self.reports.items) |report| {
            if (!try report.isSafe(self.dampener)) continue;
            count += 1;
        }
        return count;
    }
};

test "sample part 1" {
    const data =
        \\7 6 4 2 1
        \\1 2 7 8 9
        \\9 7 6 2 1
        \\1 3 2 4 5
        \\8 6 4 4 1
        \\1 3 6 7 9
    ;

    var reactor = Reactor.init(testing.allocator, false);
    defer reactor.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try reactor.addLine(line);
    }

    const count = try reactor.countSafeReports();
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\7 6 4 2 1
        \\1 2 7 8 9
        \\9 7 6 2 1
        \\1 3 2 4 5
        \\8 6 4 4 1
        \\1 3 6 7 9
    ;

    var reactor = Reactor.init(testing.allocator, true);
    defer reactor.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try reactor.addLine(line);
    }

    const count = try reactor.countSafeReports();
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, count);
}
