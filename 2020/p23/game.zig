const std = @import("std");
const testing = std.testing;

const allocator = std.heap.page_allocator;

pub const Game = struct {
    pub const SIZE = 1_000_000;

    size: usize, // actual size used
    cups: *[SIZE]usize, // value at each position
    next: *[SIZE]usize, // position for next value (linked list)
    vals: *[SIZE + 1]usize, // position where each value is -- THIS IS WITH ZERO OFFSET!
    curr: usize, // position of current value
    turn: usize, // turns played so far

    pub fn init(str: []const u8, size: usize) Game {
        var self = Game{
            .size = size,
            .cups = undefined,
            .next = undefined,
            .vals = undefined,
            .curr = 0,
            .turn = 0,
        };
        self.cups = allocator.create([SIZE]usize) catch unreachable;
        self.next = allocator.create([SIZE]usize) catch unreachable;
        self.vals = allocator.create([SIZE + 1]usize) catch unreachable;
        if (size == 0) self.size = str.len;

        self.vals[0] = std.math.maxInt(usize);
        var top: usize = 0;
        for (str) |c, p| {
            const n = c - '0';
            self.cups[p] = n;
            self.vals[n] = p;
            self.next[p] = p + 1;
            if (top < n) top = n;
        }
        var p: usize = str.len;
        while (p < self.size) : (p += 1) {
            top += 1;
            self.cups[p] = top;
            self.vals[top] = p;
            self.next[p] = p + 1;
        }
        self.next[self.size - 1] = 0;
        return self;
    }

    pub fn deinit(self: *Game) void {
        allocator.free(self.vals);
        allocator.free(self.next);
        allocator.free(self.cups);
    }

    pub fn show(self: Game) void {
        std.debug.warn("GAME ", .{});
        var p = self.curr;
        const top = (self.size * self.turn - self.turn) % self.size;
        var c: usize = 0;
        while (c < top) : (c += 1) {
            p = self.next[p];
        }
        c = 0;
        while (c < self.size) : (c += 1) {
            if (p == self.curr) {
                std.debug.warn(" ({})", .{self.cups[p]});
            } else {
                std.debug.warn(" {}", .{self.cups[p]});
            }
            p = self.next[p];
        }
        std.debug.warn("\n", .{});
    }

    pub fn play(self: *Game, turns: usize) void {
        var turn: usize = 0;
        while (turn < turns) : (turn += 1) {
            self.play_one_turn();
            // if (turn % 1000 == 0) std.debug.warn("-- move {} --\n", .{turn + 1});
            // std.debug.warn("-- move {} --\n", .{self.turn});
            // self.show();
        }
    }

    fn play_one_turn(self: *Game) void {
        var pos = self.curr;

        var first_taken: usize = 0;
        var last_taken: usize = 0;
        var first_kept: usize = 0;
        var p: usize = 0;
        while (p < 4) : (p += 1) {
            pos = self.next[pos];
            if (p < 1) first_taken = pos;
            if (p < 3) last_taken = pos;
            if (p < 4) first_kept = pos;
        }

        // find destination value, starting at current value
        var dest_val = self.cups[self.curr];
        while (true) {
            // "subtract one" from current value
            if (dest_val == 1) {
                dest_val = self.size;
            } else {
                dest_val -= 1;
            }

            // check if it is one of the taken values
            var good = true;
            pos = first_taken;
            while (pos != first_kept) : (pos = self.next[pos]) {
                if (self.cups[pos] == dest_val) {
                    good = false;
                    break;
                }
            }
            if (good) break;
        }

        var dest_pos = self.vals[dest_val];
        // std.debug.warn("destination {} at position {}\n", .{ dest_val, dest_pos });

        // rearrange next values
        self.next[self.curr] = first_kept;
        self.next[last_taken] = self.next[dest_pos];
        self.next[dest_pos] = first_taken;
        self.curr = first_kept;
        self.turn += 1;
    }

    pub fn get_state(self: *Game) usize {
        var p: usize = 0;
        while (p < self.size) : (p += 1) {
            if (self.cups[p] == 1) break;
        }
        var state: usize = 0;
        var q: usize = 0;
        while (q < self.size - 1) : (q += 1) {
            p = self.next[p];
            state *= 10;
            state += self.cups[p];
        }
        return state;
    }

    pub fn find_stars(self: *Game) usize {
        var product: usize = 1;
        var pos = self.vals[1];
        var c: usize = 0;
        while (c < 2) : (c += 1) {
            pos = self.next[pos];
            product *= pos + 1; // positions are offset ZERO, we want offset ONE
        }
        return product;
    }
};

test "sample part a" {
    const data: []const u8 = "389125467";

    var game = Game.init(data, 0);
    defer game.deinit();
    // game.show();

    game.play(10);
    try testing.expect(game.get_state() == 92658374);

    game.play(90);
    try testing.expect(game.get_state() == 67384529);
}

test "sample part b" {
    const data: []const u8 = "389125467";

    var game = Game.init(data, Game.SIZE);
    defer game.deinit();
    // game.show();

    game.play(10_000_000);
    try testing.expect(game.find_stars() == 149245887792);
}
