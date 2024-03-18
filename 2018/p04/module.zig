const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;

const Allocator = std.mem.Allocator;

pub const Shift = struct {
    const INVALID = std.math.maxInt(usize);
    const MINUTES = 60;

    const Event = struct {
        date: usize,
        time: usize,
        guard: usize,
        asleep: bool,

        pub fn init(date: usize, time: usize, guard: usize, asleep: bool) Event {
            return .{
                .date = date,
                .time = time,
                .guard = guard,
                .asleep = asleep,
            };
        }

        pub fn lessThan(_: void, l: Event, r: Event) bool {
            const od = std.math.order(l.date, r.date);
            if (od != .eq) return od == .lt;
            const ot = std.math.order(l.time, r.time);
            if (ot != .eq) return ot == .lt;
            const og = std.math.order(l.guard, r.guard);
            return og == .lt;
        }
    };

    const Stats = struct {
        total: usize,
        minutes: [MINUTES]usize,

        pub fn init() Stats {
            return .{
                .total = 0,
                .minutes = [_]usize{0} ** MINUTES,
            };
        }
    };

    allocator: Allocator,
    events: std.ArrayList(Event),
    stats: std.AutoHashMap(usize, Stats),

    pub fn init(allocator: Allocator) Shift {
        return .{
            .allocator = allocator,
            .events = std.ArrayList(Event).init(allocator),
            .stats = std.AutoHashMap(usize, Stats).init(allocator),
        };
    }

    pub fn deinit(self: *Shift) void {
        self.stats.deinit();
        self.events.deinit();
    }

    pub fn addLine(self: *Shift, line: []const u8) !void {
        var it = std.mem.tokenizeAny(u8, line, " []-:#");
        const Y = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        const M = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        const D = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        const h = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        const m = try std.fmt.parseUnsigned(usize, it.next().?, 10);

        const date = ((Y * 100) + M) * 100 + D;
        const time = h * 100 + m;

        const word = it.next().?;
        if (std.mem.eql(u8, word, "Guard")) {
            const guard = try std.fmt.parseUnsigned(usize, it.next().?, 10);
            try self.events.append(Event.init(date, time, guard, false));
            return;
        }
        if (std.mem.eql(u8, word, "falls")) {
            try self.events.append(Event.init(date, time, INVALID, true));
            return;
        }
        if (std.mem.eql(u8, word, "wakes")) {
            try self.events.append(Event.init(date, time, INVALID, false));
            return;
        }
    }

    pub fn getMostAsleep(self: *Shift, strategy: usize) !usize {
        self.sortAndFixGuards();
        try self.processEvents();
        if (strategy == 1) return self.findWithStrategyOne();
        if (strategy == 2) return self.findWithStrategyTwo();
        return 0;
    }

    fn registerGuard(self: *Shift, guard: usize, minute: usize) !void {
        const r = try self.stats.getOrPut(guard);
        if (!r.found_existing) {
            r.value_ptr.* = Stats.init();
        }
        r.value_ptr.*.total += 1;
        r.value_ptr.*.minutes[minute] += 1;
    }

    fn sortAndFixGuards(self: *Shift) void {
        std.sort.heap(Event, self.events.items, {}, Event.lessThan);
        var guard: usize = INVALID;
        for (self.events.items) |*e| {
            if (e.guard != INVALID) {
                guard = e.guard;
            }
            e.guard = guard;
        }
    }

    fn processEvents(self: *Shift) !void {
        var guard: usize = INVALID;
        var date: usize = INVALID;
        var time: usize = INVALID;
        for (self.events.items) |e| {
            if (e.guard != INVALID and guard != e.guard) {
                // new guard
                guard = e.guard;
                date = e.date;
                time = e.time;
                continue;
            }

            if (date != e.date) {
                // new day
                date = e.date;
                time = e.time;
                continue;
            }

            if (e.time >= MINUTES) {
                // time outside 00:00 ~ 00:59
                continue;
            }

            if (e.asleep) {
                // beginning of shift, remember time
                time = e.time;
                continue;
            }

            // end of shift, register asleep minutes for guard
            for (time..e.time) |minute| {
                try self.registerGuard(e.guard, minute);
            }
        }
    }

    fn findWithStrategyOne(self: Shift) !usize {
        var top_guard: usize = INVALID;
        var top_minute: usize = 0;
        var top_total: usize = 0;
        var it = self.stats.iterator();
        while (it.next()) |e| {
            const stats = e.value_ptr;
            if (top_total >= stats.total) continue;

            top_total = stats.total;
            top_guard = e.key_ptr.*;
            var guard_minute: usize = 0;
            var guard_total: usize = 0;
            for (&stats.minutes, 0..) |count, minute| {
                if (guard_total < count) {
                    guard_total = count;
                    guard_minute = minute;
                }
            }
            top_minute = guard_minute;
        }
        return top_guard * top_minute;
    }

    fn findWithStrategyTwo(self: Shift) !usize {
        var top_guard: usize = INVALID;
        var top_minute: usize = 0;
        var top_total: usize = 0;
        var it = self.stats.iterator();
        while (it.next()) |e| {
            const guard = e.key_ptr.*;
            const s = e.value_ptr.*;
            for (&s.minutes, 0..) |count, minute| {
                if (top_total < count) {
                    top_guard = guard;
                    top_total = count;
                    top_minute = minute;
                }
            }
        }
        return top_guard * top_minute;
    }
};

test "sample part 1" {
    const data =
        \\[1518-11-01 00:00] Guard #10 begins shift
        \\[1518-11-01 00:05] falls asleep
        \\[1518-11-01 00:25] wakes up
        \\[1518-11-01 00:30] falls asleep
        \\[1518-11-01 00:55] wakes up
        \\[1518-11-01 23:58] Guard #99 begins shift
        \\[1518-11-02 00:40] falls asleep
        \\[1518-11-02 00:50] wakes up
        \\[1518-11-03 00:05] Guard #10 begins shift
        \\[1518-11-03 00:24] falls asleep
        \\[1518-11-03 00:29] wakes up
        \\[1518-11-04 00:02] Guard #99 begins shift
        \\[1518-11-04 00:36] falls asleep
        \\[1518-11-04 00:46] wakes up
        \\[1518-11-05 00:03] Guard #99 begins shift
        \\[1518-11-05 00:45] falls asleep
        \\[1518-11-05 00:55] wakes up
    ;

    var shift = Shift.init(testing.allocator);
    defer shift.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try shift.addLine(line);
    }
    const code = try shift.getMostAsleep(1);
    const expected = @as(usize, 240);
    try testing.expectEqual(expected, code);
}

test "sample part 2" {
    const data =
        \\[1518-11-01 00:00] Guard #10 begins shift
        \\[1518-11-01 00:05] falls asleep
        \\[1518-11-01 00:25] wakes up
        \\[1518-11-01 00:30] falls asleep
        \\[1518-11-01 00:55] wakes up
        \\[1518-11-01 23:58] Guard #99 begins shift
        \\[1518-11-02 00:40] falls asleep
        \\[1518-11-02 00:50] wakes up
        \\[1518-11-03 00:05] Guard #10 begins shift
        \\[1518-11-03 00:24] falls asleep
        \\[1518-11-03 00:29] wakes up
        \\[1518-11-04 00:02] Guard #99 begins shift
        \\[1518-11-04 00:36] falls asleep
        \\[1518-11-04 00:46] wakes up
        \\[1518-11-05 00:03] Guard #99 begins shift
        \\[1518-11-05 00:45] falls asleep
        \\[1518-11-05 00:55] wakes up
    ;

    var shift = Shift.init(testing.allocator);
    defer shift.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try shift.addLine(line);
    }
    const code = try shift.getMostAsleep(2);
    const expected = @as(usize, 4455);
    try testing.expectEqual(expected, code);
}
