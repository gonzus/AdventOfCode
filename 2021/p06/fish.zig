const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const Fish = struct {
    pub const AGE_CYCLE = 7;
    pub const EXTRA_CYCLE = 2;
    pub const TOTAL_CYCLE = AGE_CYCLE + EXTRA_CYCLE;

    count_at_age: [TOTAL_CYCLE]usize,

    pub fn init() Fish {
        var self = Fish{ .count_at_age = [_]usize{0} ** (TOTAL_CYCLE) };
        return self;
    }

    pub fn deinit(self: *Fish) void {
        _ = self;
    }

    pub fn process_line(self: *Fish, data: []const u8) void {
        var it = std.mem.split(u8, data, ",");
        while (it.next()) |num| {
            const n = std.fmt.parseInt(usize, num, 10) catch unreachable;
            self.count_at_age[n] += 1;
            // std.debug.warn("AGE {} => {}\n", .{ n, self.count_at_age[n] });
        }
    }

    fn simulate_n_days(self: *Fish, n: usize) void {
        var day: usize = 0;
        while (day < n) : (day += 1) {
            // age 0 is special because, when we process it, we need to change
            // totals that we have not yet processed; therefore, we remember
            // its current value and process it after all other ages are done
            var age_zero: usize = self.count_at_age[0];

            var age: usize = 1; // note: start at 1
            while (age < TOTAL_CYCLE) : (age += 1) {
                self.count_at_age[age - 1] += self.count_at_age[age];
                self.count_at_age[age] -= self.count_at_age[age];
            }

            // every fish with age 0 spawns one new fish at age 6, and its own
            // age becomes 8
            self.count_at_age[AGE_CYCLE - 1] += age_zero;
            self.count_at_age[AGE_CYCLE + 1] += age_zero;
            self.count_at_age[0] -= age_zero;
        }
    }

    pub fn count_fish_after_n_days(self: *Fish, n: usize) usize {
        self.simulate_n_days(n);

        var count: usize = 0;
        var age: usize = 0;
        while (age < TOTAL_CYCLE) : (age += 1) {
            count += self.count_at_age[age];
        }
        return count;
    }
};

test "sample part a" {
    const data: []const u8 =
        \\3,4,3,1,2
    ;

    var fish = Fish.init();
    defer fish.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        fish.process_line(line);
    }

    const DAYS1 = 18;
    const DAYS2 = 80;

    const count1 = fish.count_fish_after_n_days(DAYS1);
    try testing.expect(count1 == 26);

    const count2 = fish.count_fish_after_n_days(DAYS2 - DAYS1);
    try testing.expect(count2 == 5934);
}

test "sample part b" {
    const data: []const u8 =
        \\3,4,3,1,2
    ;

    var fish = Fish.init();
    defer fish.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        fish.process_line(line);
    }

    const count = fish.count_fish_after_n_days(256);
    try testing.expect(count == 26984457539);
}
