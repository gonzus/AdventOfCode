const std = @import("std");
const assert = std.debug.assert;

pub const Sleuth = struct {
    match: Match,
    lo: u32,
    hi: u32,

    pub const Match = enum {
        TwoOrMore,
        TwoOnly,
    };

    pub fn init(match: Match) Sleuth {
        var self = Sleuth{
            .match = match,
            .lo = 0,
            .hi = 0,
        };
        return self;
    }

    pub fn search(self: *Sleuth, str: []u8) usize {
        self.lo = 0;
        self.hi = 0;
        var it = std.mem.split(u8, str, "-");
        var first = true;
        while (it.next()) |what| {
            const number = std.fmt.parseInt(u32, what, 10) catch unreachable;
            if (first) {
                self.lo = number;
            } else {
                self.hi = number;
            }
            first = false;
        }

        var n: u32 = self.lo;
        var count: usize = 0;
        while (n <= self.hi) : (n += 1) {
            const matched = switch (self.match) {
                Match.TwoOrMore => match_two_or_more(n),
                Match.TwoOnly => match_two_only(n),
            };
            if (matched) {
                count += 1;
            }
        }
        return count;
    }
};

fn match_two_or_more(n: u32) bool {
    // try out.print("GONZO {}\n", n);
    var rep: usize = 0;
    var dec: usize = 0;
    var m = n;
    var q: u8 = 99;
    while (m > 0 and dec == 0) {
        var d = @intCast(u8, m % 10);
        m /= 10;
        if (d > q) {
            dec += 1;
            break;
        }
        if (d == q) {
            rep += 1;
        }
        q = d;
    }
    if (dec > 0) {
        return false;
    }
    return (rep > 0);
}

fn match_two_only(n: u32) bool {
    // try out.print("GONZO {}\n", n);
    var rep: [10]usize = undefined;
    var j: usize = 0;
    while (j < 10) : (j += 1) {
        rep[j] = 0;
    }
    var dec: usize = 0;
    var m = n;
    var q: u8 = 99;
    while (m > 0 and dec == 0) {
        var d = @intCast(u8, m % 10);
        m /= 10;
        if (d > q) {
            dec += 1;
            break;
        }
        if (d == q) {
            rep[@intCast(usize, d)] += 1;
        }
        q = d;
    }
    if (dec > 0) {
        return false;
    }
    var c2: usize = 0;
    j = 0;
    while (j < 10) : (j += 1) {
        if (rep[j] == 1) {
            c2 += 1;
        }
    }
    return (c2 > 0);
}

test "match two or more" {
    assert(match_two_or_more(112233));
    assert(!match_two_or_more(223450));
    assert(!match_two_or_more(123789));
}

test "match exactly two" {
    assert(match_two_only(112233));
    assert(!match_two_only(123444));
    assert(match_two_only(111122));
}
