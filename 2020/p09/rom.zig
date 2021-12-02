const std = @import("std");
const testing = std.testing;

pub const ROM = struct {
    preamble_length: usize,
    line_count: usize,
    numbers: [1500]usize,
    seen: std.AutoHashMap(usize, void),

    pub fn init(len: usize) ROM {
        const allocator = std.heap.page_allocator;
        var self = ROM{
            .preamble_length = len,
            .numbers = undefined,
            .seen = std.AutoHashMap(usize, void).init(allocator),
            .line_count = 0,
        };
        return self;
    }

    pub fn deinit(self: *ROM) void {
        self.seen.deinit();
    }

    pub fn add_number(self: *ROM, line: []const u8) usize {
        const number = std.fmt.parseInt(usize, line, 10) catch unreachable;

        if (self.line_count >= self.preamble_length) {
            var found = false;
            const start = self.line_count - self.preamble_length;
            var pos: usize = start;
            while (pos < self.line_count) : (pos += 1) {
                const candidate = self.numbers[pos];
                if (candidate > number) continue;
                const missing = number - candidate;
                if (candidate == missing) continue;
                if (self.seen.contains(missing)) {
                    // std.debug.warn("FOUND {} {} = {}\n", .{ candidate, missing, number });
                    found = true;
                    break;
                }
            }
            if (!found) {
                // std.debug.warn("NOT FOUND {}\n", .{number});
                return number;
            }
            _ = self.seen.remove(self.numbers[start]);
        }

        self.numbers[self.line_count] = number;
        _ = self.seen.put(number, {}) catch unreachable;
        self.line_count += 1;
        return 0;
    }

    pub fn find_contiguous_sum(self: *ROM, target: usize) usize {
        var start: usize = 0;
        while (start < self.line_count) : (start += 1) {
            var sum: usize = 0;
            var end: usize = start;
            while (end < self.line_count) : (end += 1) {
                sum += self.numbers[end];
                if (sum < target) continue;
                if (sum > target) break;

                // std.debug.warn("FOUND SUM {} =", .{target});
                var min: usize = std.math.maxInt(usize);
                var max: usize = 0;
                var pos: usize = start;
                while (pos <= end) : (pos += 1) {
                    // std.debug.warn(" {}", .{self.numbers[pos]});
                    if (min > self.numbers[pos]) min = self.numbers[pos];
                    if (max < self.numbers[pos]) max = self.numbers[pos];
                }
                // std.debug.warn("\n", .{});
                // std.debug.warn("MIN {} MAX {}\n", .{ min, max });
                return min + max;
            }
        }
        return 0;
    }
};

test "sample" {
    const data: []const u8 =
        \\35
        \\20
        \\15
        \\25
        \\47
        \\40
        \\62
        \\55
        \\65
        \\95
        \\102
        \\117
        \\150
        \\182
        \\127
        \\219
        \\299
        \\277
        \\309
        \\576
    ;

    var rom = ROM.init(5);
    defer rom.deinit();

    var bad: usize = 0;
    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        bad = rom.add_number(line);
        if (bad > 0) {
            break;
        }
    }
    try testing.expect(bad == 127);

    const sum = rom.find_contiguous_sum(127);
    try testing.expect(sum == 62);
}
