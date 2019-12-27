const std = @import("std");
const assert = std.debug.assert;

pub const Accum = struct {
    count: usize,
    values: std.AutoHashMap(usize, isize),

    pub fn init() Accum {
        const allocator = std.heap.direct_allocator;
        return Accum{
            .count = 0,
            .values = std.AutoHashMap(usize, isize).init(allocator),
        };
    }

    pub fn deinit(self: *Accum) void {
        self.values.deinit();
    }

    pub fn reset(self: *Accum) void {
        self.count = 0;
        self.values.clear();
    }

    pub fn append(self: *Accum, value: isize) void {
        _ = self.values.put(self.count, value) catch unreachable;
        self.count += 1;
    }

    pub fn compute_sum(self: *Accum) isize {
        var total: isize = 0;
        var j: usize = 0;
        while (j < self.count) : (j += 1) {
            const value = self.values.get(j).?.value;
            total += value;
        }
        return total;
    }

    pub fn find_first_repetition(self: *Accum) isize {
        const allocator = std.heap.direct_allocator;
        var seen = std.AutoHashMap(isize, void).init(allocator);
        defer seen.deinit();

        var total: isize = 0;
        main: while (true) {
            var j: usize = 0;
            while (j < self.count) : (j += 1) {
                if (seen.contains(total)) {
                    break :main;
                }
                _ = seen.put(total, {}) catch unreachable;
                const value = self.values.get(j).?.value;
                total += value;
            }
        }
        return total;
    }

    pub fn parse(self: *Accum, str: []const u8) void {
        const value = std.fmt.parseInt(isize, std.mem.trim(u8, str, " \t"), 10) catch 0;
        self.append(value);
    }
};

test "compute sum" {
    const Data = struct {
        values: []const u8,
        expected: isize,
    };
    const data = [_]Data{
        Data{ .values = "+1, -2, +3, +1", .expected = 3 },
        Data{ .values = "+1, +1, +1", .expected = 3 },
        Data{ .values = "+1, +1, -2", .expected = 0 },
        Data{ .values = "-1, -2, -3", .expected = -6 },
    };

    var accum = Accum.init();
    defer accum.deinit();

    for (data) |d| {
        accum.reset();
        var it = std.mem.separate(d.values, ",");
        while (it.next()) |item| {
            accum.parse(item);
        }
        assert(accum.compute_sum() == d.expected);
    }
}

test "find first repetition" {
    const Data = struct {
        values: []const u8,
        expected: isize,
    };
    const data = [_]Data{
        Data{ .values = "+1, -2, +3, +1", .expected = 2 },
        Data{ .values = "+1, -1", .expected = 0 },
        Data{ .values = "+3, +3, +4, -2, -4", .expected = 10 },
        Data{ .values = "-6, +3, +8, +5, -6", .expected = 5 },
        Data{ .values = "+7, +7, -2, -7, -4", .expected = 14 },
    };

    var accum = Accum.init();
    defer accum.deinit();

    for (data) |d| {
        accum.reset();
        var it = std.mem.separate(d.values, ",");
        while (it.next()) |item| {
            accum.parse(item);
        }
        // std.debug.warn("[{}]\n", d.values);
        assert(accum.find_first_repetition() == d.expected);
    }
}
