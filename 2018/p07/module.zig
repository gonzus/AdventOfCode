const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const BitBag = @import("./util/bitmap.zig").BitBag;

const Allocator = std.mem.Allocator;

pub const Sleigh = struct {
    const Bitmap = BitBag(u32);
    const STEP_SIZE = 26;
    const BUFFER_SIZE = 100;

    allocator: Allocator,
    extra: usize,
    used: Bitmap, // which letters are used for steps
    finished: Bitmap, // which steps have been finished
    available: Bitmap, // which steps are available to be started
    required: [STEP_SIZE]Bitmap, // for each step, which steps are required before it can start
    buf: [BUFFER_SIZE]u8,
    len: usize,

    pub fn init(allocator: Allocator, extra: usize) Sleigh {
        return .{
            .allocator = allocator,
            .extra = extra,
            .used = Bitmap.init(),
            .finished = Bitmap.init(),
            .available = Bitmap.init(),
            .required = [_]Bitmap{Bitmap.init()} ** STEP_SIZE,
            .buf = undefined,
            .len = 0,
        };
    }

    pub fn addLine(self: *Sleigh, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        _ = it.next();
        const req = char2pos(it.next().?[0]);
        _ = it.next();
        _ = it.next();
        _ = it.next();
        _ = it.next();
        _ = it.next();
        const nxt = char2pos(it.next().?[0]);
        self.used.setBit(req);
        self.used.setBit(nxt);
        self.required[nxt].setBit(req);
    }

    pub fn show(self: Sleigh) void {
        std.debug.print("Sleigh with {} steps\n", .{self.used.count()});
        for (0..STEP_SIZE) |step| {
            if (!self.used.hasBit(step)) continue;
            if (self.required[step].count() <= 0) continue;
            std.debug.print("  Step {c} requires", .{pos2char(step)});
            for (0..STEP_SIZE) |required| {
                if (!self.required[step].hasBit(required)) continue;
                std.debug.print(" {c}", .{pos2char(required)});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn sortSteps(self: *Sleigh) ![]const u8 {
        self.clear();
        self.addStepsWithoutRequirements();
        while (self.available.count() > 0) {
            const first = self.available.first();
            self.available.resetBit(first);
            self.finished.setBit(first);
            self.addStepIfReady(first);
            self.buf[self.len] = pos2char(first);
            self.len += 1;
        }
        return self.buf[0..self.len];
    }

    pub fn runSteps(self: *Sleigh, workers: usize) !usize {
        self.clear();
        self.addStepsWithoutRequirements();
        var time: usize = 0; // current time in simulation
        var busy = Bitmap.init(); // which workers are busy
        var jobs = PQ.init(self.allocator, {}); // running jobs sorted by completion time
        defer jobs.deinit();
        while (self.available.count() > 0 or jobs.count() > 0) {
            if (jobs.count() > 0) {
                // process as finished at most one job, and update simulation time
                const job = jobs.remove();
                self.finished.setBit(job.step);
                self.addStepIfReady(job.step);
                busy.resetBit(job.worker);
                time = job.done;
            }
            for (0..workers) |worker| {
                // schedule as many available steps as possible on free workers
                if (self.available.count() == 0) break;
                if (busy.hasBit(worker)) continue;
                const first = self.available.first();
                self.available.resetBit(first);
                busy.setBit(worker);
                try jobs.add(Job.init(first, worker, time + self.timeRequired(first)));
            }
        }
        return time;
    }

    fn timeRequired(self: Sleigh, step: usize) usize {
        return self.extra + step + 1;
    }

    fn clear(self: *Sleigh) void {
        self.finished.clear();
        self.available.clear();
        self.len = 0;
    }

    fn addStepsWithoutRequirements(self: *Sleigh) void {
        for (0..STEP_SIZE) |step| {
            if (!self.used.hasBit(step)) continue;
            if (self.required[step].count() > 0) continue;
            self.available.setBit(step);
        }
    }

    fn addStepIfReady(self: *Sleigh, step: usize) void {
        for (0..STEP_SIZE) |next| {
            if (!self.used.hasBit(next)) continue;
            if (!self.required[next].hasBit(step)) continue;
            // count unfinished requirements for possible next
            var missing: usize = 0;
            for (0..STEP_SIZE) |required| {
                if (!self.used.hasBit(required)) continue;
                if (!self.required[next].hasBit(required)) continue;
                if (self.finished.hasBit(required)) continue;
                missing += 1;
            }
            if (missing > 0) continue;
            self.available.setBit(next);
        }
    }

    fn pos2char(pos: usize) u8 {
        const c: u8 = @intCast(pos);
        return c + 'A';
    }

    fn char2pos(char: u8) usize {
        const p: usize = @intCast(char);
        return p - 'A';
    }

    const Job = struct {
        step: usize,
        worker: usize,
        done: usize,

        pub fn init(step: usize, worker: usize, done: usize) Job {
            return .{
                .step = step,
                .worker = worker,
                .done = done,
            };
        }

        fn lessThan(_: void, l: Job, r: Job) std.math.Order {
            const do = std.math.order(l.done, r.done);
            if (do != .eq) return do;
            const ds = std.math.order(l.step, r.step);
            if (ds != .eq) return ds;
            return std.math.order(l.worker, r.worker);
        }
    };

    const PQ = std.PriorityQueue(Job, void, Job.lessThan);
};

test "sample part 1" {
    const data =
        \\Step C must be finished before step A can begin.
        \\Step C must be finished before step F can begin.
        \\Step A must be finished before step B can begin.
        \\Step A must be finished before step D can begin.
        \\Step B must be finished before step E can begin.
        \\Step D must be finished before step E can begin.
        \\Step F must be finished before step E can begin.
    ;

    var sleigh = Sleigh.init(testing.allocator, 0);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try sleigh.addLine(line);
    }
    // sleigh.show();

    const steps = try sleigh.sortSteps();
    const expected = "CABDFE";
    try testing.expectEqualStrings(expected, steps);
}

test "sample part 2" {
    const data =
        \\Step C must be finished before step A can begin.
        \\Step C must be finished before step F can begin.
        \\Step A must be finished before step B can begin.
        \\Step A must be finished before step D can begin.
        \\Step B must be finished before step E can begin.
        \\Step D must be finished before step E can begin.
        \\Step F must be finished before step E can begin.
    ;

    var sleigh = Sleigh.init(testing.allocator, 0);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try sleigh.addLine(line);
    }
    // sleigh.show();

    const elapsed = try sleigh.runSteps(2);
    const expected = @as(usize, 15);
    try testing.expectEqual(expected, elapsed);
}
