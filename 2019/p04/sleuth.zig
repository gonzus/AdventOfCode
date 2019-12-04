const std = @import("std");

pub const Sleuth = struct {
    lo: i32,
    hi: i32,
    count: usize,

    pub fn init() Sleuth {
        var self = Sleuth{
            .lo = 0,
            .hi = 0,
            .count = 0,
        };
        return self;
    }

    pub fn search(self: *Sleuth, str: []u8, match: fn (n: i32) bool) !void {
        self.lo = 0;
        self.hi = 0;
        var it = std.mem.separate(str, "-");
        var first = true;
        while (it.next()) |what| {
            const number = try std.fmt.parseInt(i32, what, 10);
            if (first) {
                self.lo = number;
            } else {
                self.hi = number;
            }
            first = false;
        }

        var n: i32 = self.lo;
        self.count = 0;
        while (n <= self.hi) : (n += 1) {
            if (match(n)) {
                self.count += 1;
            }
        }
    }
};
