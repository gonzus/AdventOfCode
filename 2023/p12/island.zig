const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Record = struct {
    const DP = struct {
        allocator: Allocator,
        data: [][][]usize,
        springs: []const u8,
        counts: []usize,

        pub fn init(allocator: Allocator, springs: []const u8, counts: []usize) !DP {
            var self = DP{
                .allocator = allocator,
                .data = undefined,
                .springs = springs,
                .counts = counts,
            };
            self.data = try self.allocator.alloc([][]usize, springs.len + 1);
            for (self.data) |*d1| {
                d1.* = try self.allocator.alloc([]usize, counts.len + 1);
                for (d1.*) |*d2| {
                    d2.* = try self.allocator.alloc(usize, springs.len + 1);
                    for (d2.*) |*v| {
                        v.* = 0;
                    }
                }
            }
            return self;
        }

        pub fn deinit(self: *DP) void {
            for (self.data) |*d1| {
                for (d1.*) |*d2| {
                    self.allocator.free(d2.*);
                }
                self.allocator.free(d1.*);
            }
            self.allocator.free(self.data);
        }

        fn compute(self: DP) void {
            const chars = [_]u8{ '.', '#' };
            const slen = self.springs.len;
            const clen = self.counts.len;

            self.data[slen][clen][0] = 1;
            self.data[slen][clen - 1][self.counts[clen - 1]] = 1;
            for (0..slen) |rev_spos| {
                const spos = slen - rev_spos - 1;
                for (self.counts, 0..) |max_count, group| {
                    for (0..max_count + 1) |count| {
                        for (chars) |c| {
                            if (self.springs[spos] == c or self.springs[spos] == '?') {
                                if (c == '.' and count == 0) {
                                    self.data[spos][group][count] += self.data[spos + 1][group][0];
                                } else if (c == '.' and group < clen and self.counts[group] == count) {
                                    self.data[spos][group][count] += self.data[spos + 1][group + 1][0];
                                } else if (c == '#') {
                                    self.data[spos][group][count] += self.data[spos + 1][group][count + 1];
                                }
                            }
                        }
                    }
                }
                if (self.springs[spos] == '.' or self.springs[spos] == '?') {
                    self.data[spos][clen][0] += self.data[spos + 1][clen][0];
                }
            }
        }

        pub fn search(self: DP) usize {
            self.compute();
            return self.data[0][0][0];
        }
    };

    allocator: Allocator,
    foldings: usize,
    springs: std.ArrayList(u8),
    counts: std.ArrayList(usize),
    sum: usize,

    pub fn init(allocator: Allocator, foldings: usize) Record {
        var self = Record{
            .allocator = allocator,
            .foldings = foldings,
            .springs = std.ArrayList(u8).init(allocator),
            .counts = std.ArrayList(usize).init(allocator),
            .sum = 0,
        };
        return self;
    }

    pub fn deinit(self: *Record) void {
        self.counts.deinit();
        self.springs.deinit();
    }

    fn reset(self: *Record) void {
        self.springs.clearRetainingCapacity();
        self.counts.clearRetainingCapacity();
    }

    fn process(self: *Record) !void {
        if (self.foldings == 1) {
            var dp = try DP.init(self.allocator, self.springs.items, self.counts.items);
            defer dp.deinit();
            self.sum += dp.search();
            return;
        }

        var springs = std.ArrayList(u8).init(self.allocator);
        defer springs.deinit();

        var counts = std.ArrayList(usize).init(self.allocator);
        defer counts.deinit();

        for (0..self.foldings) |p| {
            if (p > 0) {
                try springs.append('?');
            }
            for (self.springs.items) |c| {
                try springs.append(c);
            }

            for (self.counts.items) |c| {
                try counts.append(c);
            }
        }

        var dp = try DP.init(self.allocator, springs.items, counts.items);
        defer dp.deinit();
        self.sum += dp.search();
    }

    pub fn addLine(self: *Record, line: []const u8) !void {
        self.reset();

        var chunk_it = std.mem.tokenizeScalar(u8, line, ' ');
        const spring_chunk = chunk_it.next().?;
        const count_chunk = chunk_it.next().?;

        for (spring_chunk) |c| {
            try self.springs.append(c);
        }

        var count_it = std.mem.tokenizeScalar(u8, count_chunk, ',');
        while (count_it.next()) |str| {
            const count = try std.fmt.parseUnsigned(usize, str, 10);
            try self.counts.append(count);
        }

        try self.process();
    }

    pub fn getSumArrangements(self: *Record) !usize {
        return self.sum;
    }
};

test "sample part 1" {
    const data =
        \\???.### 1,1,3
        \\.??..??...?##. 1,1,3
        \\?#?#?#?#?#?#?#? 1,3,1,6
        \\????.#...#... 4,1,1
        \\????.######..#####. 1,6,5
        \\?###???????? 3,2,1
    ;

    var record = Record.init(std.testing.allocator, 1);
    defer record.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try record.addLine(line);
    }

    const count = try record.getSumArrangements();
    const expected = @as(usize, 21);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\???.### 1,1,3
        \\.??..??...?##. 1,1,3
        \\?#?#?#?#?#?#?#? 1,3,1,6
        \\????.#...#... 4,1,1
        \\????.######..#####. 1,6,5
        \\?###???????? 3,2,1
    ;

    var record = Record.init(std.testing.allocator, 5);
    defer record.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try record.addLine(line);
    }

    const count = try record.getSumArrangements();
    const expected = @as(usize, 525152);
    try testing.expectEqual(expected, count);
}
