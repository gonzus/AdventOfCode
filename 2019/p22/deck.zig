const std = @import("std");
const assert = std.debug.assert;

pub const Deck = struct {
    const MAX_SIZE = 10010;

    size: isize,
    first: isize,
    step: isize,

    pub fn init(size: isize) Deck {
        var self = Deck{
            .size = size,
            .first = 0,
            .step = 1,
        };
        return self;
    }

    pub fn deinit(self: *Deck) void {}

    pub fn get_card(self: *Deck, pos: isize) isize {
        var r = pos * self.step;
        r = @mod(r, self.size);
        var p = self.first + self.size + r;
        p = @mod(p, self.size);
        return p;
    }

    pub fn get_pos(self: *Deck, card: isize) isize {
        var p: isize = 0;
        while (p < self.size) : (p += 1) {
            const c = self.get_card(p);
            if (c == card) return p;
        }
        return 0;
    }

    pub fn deal_into_new_stack(self: *Deck) void {
        self.first = @mod(self.first - self.step, self.size);
        self.step = -self.step;
    }

    pub fn cut_N_cards(self: *Deck, n: isize) void {
        var r = n * self.step;
        r = @mod(r, self.size);
        self.first += self.size + r;
        self.first = @mod(self.first, self.size);
    }

    pub fn deal_with_increment_N(self: *Deck, n: isize) void {
        const step: i128 = self.step;
        const mod: i128 = mod_inverse(n, self.size);
        const r: i128 = @mod(step * mod, self.size);
        self.step = @intCast(isize, r);
    }

    pub fn mod_inverse(a: isize, m: isize) isize {
        if (m == 1) return 0;

        var p: isize = m;
        var z: isize = a;
        var y: isize = 0;
        var x: isize = 1;
        while (z > 1) {
            // q is quotient
            const q: isize = @divTrunc(z, p);

            // p is remainder now, process same as Euclid's algorithm
            const tz = p;
            p = @mod(z, p);
            z = tz;

            // Update y and x
            const tx = y;
            y = x - q * y;
            x = tx;
        }

        // Make sure x is positive
        if (x < 0) x += m;

        return x;
    }

    pub fn mod_power(b: isize, e: isize, m: isize) isize {
        var res: isize = 1;
        var bb: isize = @mod(b, m); // Update b if it is more than or equal to m
        var ee: isize = e;
        while (ee > 0) {
            // If e is odd, multiply b with result
            var p1: i128 = res;
            p1 *= bb;
            if (ee & 1 > 0) res = @intCast(isize, @mod(p1, m));

            // e must be even now
            ee >>= 1; // e = e/2
            var p2: i128 = bb;
            p2 *= bb;
            bb = @intCast(isize, @mod(p2, m));
        }
        return res;
    }

    pub fn run_line(self: *Deck, line: []const u8) void {
        const ops = [_][]const u8{
            "deal into new stack",
            "cut",
            "deal with increment",
        };
        for (ops) |op, index| {
            if (line.len < op.len) continue;
            if (std.mem.compare(u8, line[0..op.len], op) == std.mem.Compare.Equal) {
                var arg: isize = 0;
                if (line.len > op.len) {
                    arg = std.fmt.parseInt(i32, line[op.len + 1 ..], 10) catch unreachable;
                }
                // std.debug.warn("WILL RUN [{}] [{}]\n", op, arg);
                if (index == 0) {
                    self.deal_into_new_stack();
                }
                if (index == 1) {
                    self.cut_N_cards(arg);
                }
                if (index == 2) {
                    self.deal_with_increment_N(arg);
                }
                // self.show();
            }
        }
    }

    pub fn show(self: *Deck) void {
        std.debug.warn("DECK size {}, first {}, step {}\n", self.size, self.first, self.step);
    }
};

test "new deck is sorted" {
    const SIZE = 5;
    var s: isize = 1;
    while (s < SIZE) : (s += 1) {
        var deck = Deck.init(s);
        defer deck.deinit();
        var j: isize = 0;
        while (j < s) : (j += 1) {
            assert(deck.get_card(j) == j);
        }
    }
}

test "new deck dealt into new stack is reversed" {
    // std.debug.warn("\n");
    const SIZE = 5;
    var s: isize = 1;
    while (s < SIZE) : (s += 1) {
        var deck = Deck.init(s);
        defer deck.deinit();
        deck.deal_into_new_stack();
        var j: isize = 0;
        while (j < s) : (j += 1) {
            const c = deck.get_card(s - j - 1);
            // std.debug.warn("S {}: C {} is {}, expected {}\n", s, j, c, j);
            assert(deck.get_card(s - j - 1) == j);
        }
    }
}

test "cut N cards, positive" {
    // std.debug.warn("\n");
    const SIZE = 10;
    var deck = Deck.init(SIZE);
    defer deck.deinit();
    deck.cut_N_cards(3);
    // deck.show();
}

test "cut N cards, negative" {
    // std.debug.warn("\n");
    const SIZE = 10;
    var deck = Deck.init(SIZE);
    defer deck.deinit();
    deck.cut_N_cards(-4);
    // deck.show();
}

test "dealt with increment N" {
    // std.debug.warn("\n");
    const SIZE = 10;
    var deck = Deck.init(SIZE);
    defer deck.deinit();
    deck.deal_with_increment_N(3);
    // deck.show();
}

test "shuffle 1" {
    // std.debug.warn("\n");
    const data =
        \\deal with increment 7
        \\deal into new stack
        \\deal into new stack
    ;
    const expected = "0 3 6 9 2 5 8 1 4 7";
    const SIZE = 10;
    var deck = Deck.init(SIZE);
    defer deck.deinit();
    var itd = std.mem.separate(data, "\n");
    while (itd.next()) |line| {
        deck.run_line(line);
    }
    var ite = std.mem.separate(expected, " ");
    var p: isize = 0;
    while (ite.next()) |s| : (p += 1) {
        const card = @intCast(isize, s[0] - '0');
        const got = deck.get_card(p);
        assert(deck.get_card(p) == card);
    }
}

test "shuffle 2" {
    // std.debug.warn("\n");
    const data =
        \\cut 6
        \\deal with increment 7
        \\deal into new stack
    ;
    const expected = "3 0 7 4 1 8 5 2 9 6";
    const SIZE = 10;
    var deck = Deck.init(SIZE);
    defer deck.deinit();
    var itd = std.mem.separate(data, "\n");
    while (itd.next()) |line| {
        deck.run_line(line);
    }
    var ite = std.mem.separate(expected, " ");
    var p: isize = 0;
    while (ite.next()) |s| : (p += 1) {
        const card = @intCast(isize, s[0] - '0');
        const got = deck.get_card(p);
        assert(deck.get_card(p) == card);
    }
}

test "shuffle 3" {
    // std.debug.warn("\n");
    const data =
        \\deal with increment 7
        \\deal with increment 9
        \\cut -2
    ;
    const expected = "6 3 0 7 4 1 8 5 2 9";
    const SIZE = 10;
    var deck = Deck.init(SIZE);
    defer deck.deinit();
    var itd = std.mem.separate(data, "\n");
    while (itd.next()) |line| {
        deck.run_line(line);
    }
    var ite = std.mem.separate(expected, " ");
    var p: isize = 0;
    while (ite.next()) |s| : (p += 1) {
        const card = @intCast(isize, s[0] - '0');
        const got = deck.get_card(p);
        assert(deck.get_card(p) == card);
    }
}

test "shuffle 4" {
    // std.debug.warn("\n");
    const data =
        \\deal into new stack
        \\cut -2
        \\deal with increment 7
        \\cut 8
        \\cut -4
        \\deal with increment 7
        \\cut 3
        \\deal with increment 9
        \\deal with increment 3
        \\cut -1
    ;
    const expected = "9 2 5 8 1 4 7 0 3 6";
    const SIZE = 10;
    var deck = Deck.init(SIZE);
    defer deck.deinit();
    var itd = std.mem.separate(data, "\n");
    while (itd.next()) |line| {
        deck.run_line(line);
    }
    var ite = std.mem.separate(expected, " ");
    var p: isize = 0;
    while (ite.next()) |s| : (p += 1) {
        const card = @intCast(isize, s[0] - '0');
        const got = deck.get_card(p);
        assert(deck.get_card(p) == card);
    }
}
