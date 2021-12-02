const std = @import("std");
const testing = std.testing;

const allocator = std.heap.page_allocator;

pub const Puzzle = struct {
    said: std.AutoHashMap(usize, usize),
    turn: usize,
    last: usize,
    progress: bool,

    pub fn init(progress: bool) Puzzle {
        var self = Puzzle{
            .said = std.AutoHashMap(usize, usize).init(allocator),
            .turn = 0,
            .last = 0,
            .progress = progress,
        };
        return self;
    }

    pub fn deinit(self: *Puzzle) void {
        self.said.deinit();
    }

    pub fn run(self: *Puzzle, seed: []const u8, turns: usize) usize {
        var it = std.mem.tokenize(u8, seed, ",");
        var first: bool = true;
        var curr: usize = 0;
        while (it.next()) |num| {
            curr = std.fmt.parseInt(usize, num, 10) catch unreachable;
            if (!first) {
                _ = self.said.put(self.last, self.turn) catch unreachable;
            }
            first = false;
            self.last = curr;
            self.turn += 1;
            // std.debug.warn("SEED {} {}\n", .{ self.turn, self.last });
        }
        var show_progress_every: usize = turns / 20;
        if (show_progress_every < 1_000) show_progress_every = 1_000;
        while (self.turn < turns) {
            var pos = self.turn;
            if (self.said.contains(self.last)) {
                pos = self.said.get(self.last).?;
                _ = self.said.remove(self.last);
            }
            _ = self.said.put(self.last, self.turn) catch unreachable;
            self.last = self.turn - pos;
            self.turn += 1;
            if (self.progress and self.turn % show_progress_every == 0) {
                const progress: usize = 100 * self.turn / turns;
                std.debug.warn("GAME {}% {} {}\n", .{ progress, self.turn, self.last });
            }
        }
        return self.last;
    }
};

test "sample short 1" {
    const data: []const u8 = "0,3,6";

    var puzzle = Puzzle.init(false);
    defer puzzle.deinit();

    const number = puzzle.run(data, 2020);
    try testing.expect(number == 436);
}

test "sample short 2" {
    const data: []const u8 = "1,3,2";

    var puzzle = Puzzle.init(false);
    defer puzzle.deinit();

    const number = puzzle.run(data, 2020);
    try testing.expect(number == 1);
}

test "sample short 3" {
    const data: []const u8 = "2,1,3";

    var puzzle = Puzzle.init(false);
    defer puzzle.deinit();

    const number = puzzle.run(data, 2020);
    try testing.expect(number == 10);
}

test "sample short 4" {
    const data: []const u8 = "1,2,3";

    var puzzle = Puzzle.init(false);
    defer puzzle.deinit();

    const number = puzzle.run(data, 2020);
    try testing.expect(number == 27);
}

test "sample short 5" {
    const data: []const u8 = "2,3,1";

    var puzzle = Puzzle.init(false);
    defer puzzle.deinit();

    const number = puzzle.run(data, 2020);
    try testing.expect(number == 78);
}

test "sample short 6" {
    const data: []const u8 = "3,2,1";

    var puzzle = Puzzle.init(false);
    defer puzzle.deinit();

    const number = puzzle.run(data, 2020);
    try testing.expect(number == 438);
}

test "sample short 7" {
    const data: []const u8 = "3,1,2";

    var puzzle = Puzzle.init(false);
    defer puzzle.deinit();

    const number = puzzle.run(data, 2020);
    try testing.expect(number == 1836);
}

// ------------------------------------------------------------------
// All these tests pass, but they take longer (minutes on my laptop).
// ------------------------------------------------------------------

// test "sample long 1" {
//     const data: []const u8 = "0,3,6";
//
//     var puzzle = Puzzle.init(true);
//     defer puzzle.deinit();
//
//     const number = puzzle.run(data, 30000000);
//     try testing.expect(number == 175594);
// }
//
// test "sample long 2" {
//     const data: []const u8 = "1,3,2";
//
//     var puzzle = Puzzle.init(true);
//     defer puzzle.deinit();
//
//     const number = puzzle.run(data, 30000000);
//     try testing.expect(number == 2578);
// }
//
// test "sample long 3" {
//     const data: []const u8 = "2,1,3";
//
//     var puzzle = Puzzle.init(true);
//     defer puzzle.deinit();
//
//     const number = puzzle.run(data, 30000000);
//     try testing.expect(number == 3544142);
// }
//
// test "sample long 4" {
//     const data: []const u8 = "1,2,3";
//
//     var puzzle = Puzzle.init(true);
//     defer puzzle.deinit();
//
//     const number = puzzle.run(data, 30000000);
//     try testing.expect(number == 261214);
// }
//
// test "sample long 5" {
//     const data: []const u8 = "2,3,1";
//
//     var puzzle = Puzzle.init(true);
//     defer puzzle.deinit();
//
//     const number = puzzle.run(data, 30000000);
//     try testing.expect(number == 6895259);
// }
//
// test "sample long 6" {
//     const data: []const u8 = "3,2,1";
//
//     var puzzle = Puzzle.init(true);
//     defer puzzle.deinit();
//
//     const number = puzzle.run(data, 30000000);
//     try testing.expect(number == 18);
// }
//
// test "sample long 7" {
//     const data: []const u8 = "3,1,2";
//
//     var puzzle = Puzzle.init(true);
//     defer puzzle.deinit();
//
//     const number = puzzle.run(data, 30000000);
//     try testing.expect(number == 362);
// }
