const std = @import("std");
const testing = std.testing;

pub const Module = struct {
    const Range = struct {
        lo: usize,
        hi: usize,

        pub fn sumInvalid(self: Range, use_any: bool) !usize {
            var sum: usize = 0;
            for (self.lo..self.hi + 1) |id| {
                var buf: [32]u8 = undefined;
                const txt = try std.fmt.bufPrint(&buf, "{}", .{id});
                if (!use_any and txt.len % 2 != 0) continue;
                const mid = txt.len / 2;
                var dupe = false;
                var len = mid;
                while (len > 0) : (len -= 1) {
                    defer {
                        if (!use_any) len = 1; // only try once
                    }
                    if (txt.len % len != 0) continue;
                    var ok = true;
                    var start = len;
                    while (start < txt.len) : (start += len) {
                        if (!std.mem.eql(u8, txt[0..len], txt[start .. start + len])) {
                            ok = false;
                            break;
                        }
                    }
                    if (!ok) continue;
                    dupe = true;
                    break;
                }
                if (!dupe) continue;
                sum += id;
            }
            return sum;
        }
    };

    alloc: std.mem.Allocator,
    ranges: std.ArrayList(Range),
    use_any: bool,

    pub fn init(alloc: std.mem.Allocator, use_any: bool) Module {
        return .{
            .alloc = alloc,
            .ranges = .{},
            .use_any = use_any,
        };
    }

    pub fn deinit(self: *Module) void {
        self.ranges.deinit(self.alloc);
    }

    pub fn parseInput(self: *Module, data: []const u8) !void {
        var it_lines = std.mem.splitScalar(u8, data, '\n');
        while (it_lines.next()) |line| {
            var it = std.mem.tokenizeScalar(u8, line, ',');
            while (it.next()) |chunk| {
                var itd = std.mem.tokenizeScalar(u8, chunk, '-');
                var r: Range = undefined;
                r.lo = try std.fmt.parseUnsigned(usize, itd.next().?, 10);
                r.hi = try std.fmt.parseUnsigned(usize, itd.next().?, 10);
                try self.ranges.append(self.alloc, r);
            }
        }
    }

    pub fn getSumInvalidIds(self: *Module) !usize {
        var total: usize = 0;
        for (self.ranges.items) |r| {
            const sum = try r.sumInvalid(self.use_any);
            // std.debug.print("{}: {} - {}\n", .{ sum, r.lo, r.hi });
            total += sum;
        }
        return total;
    }
};

test "sample part 1" {
    const data =
        \\11-22,95-115,998-1012,1188511880-1188511890,222220-222224,
        \\1698522-1698528,446443-446449,38593856-38593862,565653-565659,
        \\824824821-824824827,2121212118-2121212124
    ;

    var module = Module.init(testing.allocator, false);
    defer module.deinit();
    try module.parseInput(data);

    const sum = try module.getSumInvalidIds();
    const expected = @as(usize, 1227775554);
    try testing.expectEqual(expected, sum);
}

test "sample part 2" {
    const data =
        \\11-22,95-115,998-1012,1188511880-1188511890,222220-222224,
        \\1698522-1698528,446443-446449,38593856-38593862,565653-565659,
        \\824824821-824824827,2121212118-2121212124
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();
    try module.parseInput(data);

    const sum = try module.getSumInvalidIds();
    const expected = @as(usize, 4174379265);
    try testing.expectEqual(expected, sum);
}
