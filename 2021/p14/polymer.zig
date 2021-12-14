const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

const desc_usize = std.sort.desc(usize);

pub const Polymer = struct {
    const Pair = struct {
        e0: u8,
        e1: u8,

        pub fn init(e0: u8, e1: u8) Pair {
            var self = Pair{
                .e0 = e0,
                .e1 = e1,
            };
            return self;
        }

        pub fn deinit(_: *Pair) void {}
    };

    cur: usize,
    pairs: [2]std.AutoHashMap(Pair, usize),
    rules: std.AutoHashMap(Pair, u8),
    counts: [26]usize,
    first: u8,
    in_rules: bool,

    pub fn init() Polymer {
        var self = Polymer{
            .cur = 0,
            .pairs = undefined,
            .rules = std.AutoHashMap(Pair, u8).init(allocator),
            .counts = [_]usize{0} ** 26,
            .first = 0,
            .in_rules = false,
        };
        self.pairs[0] = std.AutoHashMap(Pair, usize).init(allocator);
        self.pairs[1] = std.AutoHashMap(Pair, usize).init(allocator);
        return self;
    }

    pub fn deinit(self: *Polymer) void {
        self.pairs[1].deinit();
        self.pairs[0].deinit();
        self.rules.deinit();
    }

    pub fn process_line(self: *Polymer, data: []const u8) !void {
        if (data.len == 0) {
            self.in_rules = true;
            return;
        }
        if (!self.in_rules) {
            var e0: u8 = 0;
            for (data) |e1| {
                // Remember first element to include it in the count
                if (self.first == 0) self.first = e1;

                if (e0 != 0) {
                    const p = Pair.init(e0, e1);
                    try self.count_pair(true, p, 1);
                }
                e0 = e1;
            }
        } else {
            var p: Pair = undefined;
            var pos: usize = 0;
            var it = std.mem.split(u8, data, " -> ");
            while (it.next()) |what| : (pos += 1) {
                if (pos == 0) {
                    p = Pair.init(what[0], what[1]);
                    continue;
                }
                if (pos == 1) {
                    // std.debug.warn("RULE {c}{c} -> {c}\n", .{ p.e0, p.e1, what[0] });
                    try self.rules.put(p, what[0]);
                    continue;
                }
                unreachable;
            }
        }
    }

    pub fn get_diff_top_elements_after_n_steps(self: *Polymer, steps: usize) !usize {
        var s: usize = 0;
        while (s < steps) : (s += 1) {
            // std.debug.warn("STEP {}\n", .{s});
            try self.make_step();
        }

        return try self.get_diff_top_elements();
    }

    fn get_diff_top_elements(self: Polymer) !usize {
        var counts = std.ArrayList(usize).init(allocator);
        defer counts.deinit();
        for (self.counts) |c| {
            // skip zeroes so that it is easier to find the extremes
            if (c == 0) continue;
            try counts.append(c);
        }
        std.sort.sort(usize, counts.items, {}, desc_usize);
        return counts.items[0] - counts.items[counts.items.len - 1];
    }

    fn count_pair(self: *Polymer, first: bool, p: Pair, n: usize) !void {
        const pos = if (first) self.cur else (1 - self.cur);
        var c = self.pairs[pos].get(p) orelse 0;
        // std.debug.warn("CHANGE {c}{c}: {} + {} -> {}\n", .{ p.e0, p.e1, c, n, c + n });
        try self.pairs[pos].put(p, c + n);
    }

    fn count_element(self: *Polymer, e: u8, n: usize) void {
        const pos = e - 'A';
        self.counts[pos] += n;
    }

    fn make_step(self: *Polymer) !void {
        const nxt = 1 - self.cur;
        self.pairs[nxt].clearRetainingCapacity();
        self.counts = [_]usize{0} ** 26;
        var it = self.pairs[self.cur].iterator();
        while (it.next()) |entry| {
            const p = entry.key_ptr.*;
            if (!self.rules.contains(p)) continue;

            const n = entry.value_ptr.*;
            const e = self.rules.get(p).?;
            // std.debug.warn("USING {c}{c} -> {c}\n", .{ p.e0, p.e1, e });
            try self.count_pair(false, Pair.init(p.e0, e), n);
            try self.count_pair(false, Pair.init(e, p.e1), n);
            self.count_element(e, n);
            self.count_element(p.e1, n);
        }
        self.count_element(self.first, 1);
        self.cur = nxt;
    }
};

test "sample part a" {
    const data: []const u8 =
        \\NNCB
        \\
        \\CH -> B
        \\HH -> N
        \\CB -> H
        \\NH -> C
        \\HB -> C
        \\HC -> B
        \\HN -> C
        \\NN -> C
        \\BH -> H
        \\NC -> B
        \\NB -> B
        \\BN -> B
        \\BB -> N
        \\BC -> B
        \\CC -> N
        \\CN -> C
    ;

    var polymer = Polymer.init();
    defer polymer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try polymer.process_line(line);
    }
    const diff_top_elements = try polymer.get_diff_top_elements_after_n_steps(10);
    try testing.expect(diff_top_elements == 1588);
}

test "sample part b" {
    const data: []const u8 =
        \\NNCB
        \\
        \\CH -> B
        \\HH -> N
        \\CB -> H
        \\NH -> C
        \\HB -> C
        \\HC -> B
        \\HN -> C
        \\NN -> C
        \\BH -> H
        \\NC -> B
        \\NB -> B
        \\BN -> B
        \\BB -> N
        \\BC -> B
        \\CC -> N
        \\CN -> C
    ;

    var polymer = Polymer.init();
    defer polymer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try polymer.process_line(line);
    }
    const diff_top_elements = try polymer.get_diff_top_elements_after_n_steps(40);
    try testing.expect(diff_top_elements == 2188189693529);
}
