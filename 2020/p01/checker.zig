const std = @import("std");
const testing = std.testing;

pub const Checker = struct {
    seen: std.AutoHashMap(i32, void),

    pub fn init() Checker {
        const allocator = std.heap.page_allocator;
        var self = Checker{
            .seen = std.AutoHashMap(i32, void).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Checker) void {
        self.seen.deinit();
    }

    pub fn add(self: *Checker, value: i32) void {
        if (self.seen.contains(value)) {
            return;
        }
        _ = self.seen.put(value, {}) catch unreachable;
    }

    pub fn check2(self: Checker, wanted: i32) i32 {
        var it = self.seen.iterator();
        while (it.next()) |kv| {
            const value = kv.key_ptr.*;
            const delta = wanted - value;
            if (self.seen.contains(delta)) {
                return value * delta;
            }
        }
        return 0;
    }

    pub fn check3(self: Checker, wanted: i32) i32 {
        var it1 = self.seen.iterator();
        while (it1.next()) |kv1| {
            const value = kv1.key_ptr.*;
            var it2 = self.seen.iterator();
            while (it2.next()) |kv2| {
                const other = kv2.key_ptr.*;
                const delta = wanted - value - other;
                if (self.seen.contains(delta)) {
                    return value * other * delta;
                }
            }
        }
        return 0;
    }
};

test "sample" {
    var checker = Checker.init();
    defer checker.deinit();

    const data: []const u8 =
        \\1721
        \\979
        \\366
        \\299
        \\675
        \\1456
    ;
    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        const value = std.fmt.parseInt(i32, line, 10) catch unreachable;
        checker.add(value);
    }

    try testing.expect(checker.check2(2020) == 514579);
    try testing.expect(checker.check3(2020) == 241861950);
}
