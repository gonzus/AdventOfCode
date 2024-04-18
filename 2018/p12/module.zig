const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Tunnel = struct {
    const StringId = StringTable.StringId;
    const INFINITY = std.math.maxInt(isize);
    const RULE_SIZE = 32;
    const POT_SIZE = 1000;
    const POT_OFFSET = POT_SIZE / 2;

    const Memory = struct {
        iter: usize,
        score: isize,
    };

    pots: [2][POT_SIZE]u8,
    rules: [RULE_SIZE]bool,
    pos: usize,
    beg: isize,
    end: isize,
    buf: [1024]u8,
    strtab: StringTable,
    seen: std.AutoHashMap(StringId, Memory),

    pub fn init(allocator: Allocator) Tunnel {
        var self = Tunnel{
            .pots = undefined,
            .rules = [_]bool{false} ** RULE_SIZE,
            .pos = 0,
            .beg = INFINITY,
            .end = -INFINITY,
            .buf = undefined,
            .strtab = StringTable.init(allocator),
            .seen = std.AutoHashMap(StringId, Memory).init(allocator),
        };
        for (self.pots, 0..) |_, p| {
            self.pots[p] = [_]u8{'.'} ** POT_SIZE;
        }
        return self;
    }

    pub fn deinit(self: *Tunnel) void {
        self.seen.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Tunnel, line: []const u8) !void {
        if (line.len == 0) return;

        if (line[0] == '.' or line[0] == '#') {
            var it = std.mem.tokenizeAny(u8, line, " =>");
            const src = it.next().?;
            const tgt = it.next().?;
            var pos: usize = 0;
            for (src) |c| {
                pos <<= 1;
                if (c == '#') pos += 1;
            }
            self.rules[pos] = tgt[0] == '#';
        } else {
            var it = std.mem.tokenizeAny(u8, line, ": ");
            _ = it.next();
            _ = it.next();
            const state = it.next().?;
            for (state, 0..) |c, pos| {
                const p: usize = @intCast(POT_OFFSET + pos);
                self.pots[self.pos][p] = c;
                if (c == '#') {
                    if (self.beg > pos) self.beg = @intCast(pos);
                    if (self.end < pos) self.end = @intCast(pos);
                }
            }
        }
    }

    pub fn show(self: *Tunnel) void {
        std.debug.print("Tunnel beg {} end {}\n", .{ self.beg, self.end });
        std.debug.print("{s}\n", .{self.getPots()});
        for (&self.rules, 0..) |r, p| {
            var buf: [5]u8 = undefined;
            std.mem.copyForwards(u8, &buf, ".....");
            var pos: usize = 4;
            var num = p;
            while (true) : (pos -= 1) {
                buf[pos] = if (num % 2 == 0) '.' else '#';
                num /= 2;
                if (num == 0) break;
            }
            const l: u8 = if (r) '#' else '.';
            std.debug.print("Rule {s} => {c}\n", .{ buf[0..5], l });
        }
    }

    pub fn runIterations(self: *Tunnel, count: usize) !isize {
        var score: isize = 0;
        for (0..count) |iter| {
            try self.step();
            const pots = self.getPots();
            const current = self.getScore();
            if (self.strtab.contains(pots)) {
                const id = self.strtab.get_pos(pots).?;
                const memory = self.seen.get(id).?;
                const delta_iter: isize = @intCast(iter - memory.iter);
                const delta_score = current - memory.score;
                const left_iter: isize = @intCast(count - iter);
                // NOTE: this is only valid when delta_iter is 1;
                // we should do a combination of div & mod here, but I cannot be arsed.
                score = delta_score * @divTrunc(left_iter, delta_iter) + memory.score;
                break;
            } else {
                const id = try self.strtab.add(pots);
                score = current;
                try self.seen.put(id, Memory{ .iter = iter, .score = score });
            }
        }
        return score;
    }

    fn getPots(self: *Tunnel) []const u8 {
        var len: usize = 0;
        var pos = self.beg;
        while (pos <= self.end) : (pos += 1) {
            const p: usize = @intCast(POT_OFFSET + pos);
            self.buf[len] = self.pots[self.pos][p];
            len += 1;
        }
        return self.buf[0..len];
    }

    fn getScore(self: Tunnel) isize {
        var total: isize = 0;
        var pos = self.beg;
        while (pos <= self.end) : (pos += 1) {
            const p: usize = @intCast(POT_OFFSET + pos);
            if (self.pots[self.pos][p] != '#') continue;
            total += pos;
        }
        return total;
    }

    fn step(self: *Tunnel) !void {
        const nxt = 1 - self.pos;
        var beg: isize = INFINITY;
        var end: isize = -INFINITY;
        var pos = self.beg - 2;
        while (pos <= self.end + 2) : (pos += 1) {
            var r: usize = 0;
            var d: isize = -2;
            while (d <= 2) : (d += 1) {
                const p: usize = @intCast(POT_OFFSET + pos + d);
                r <<= 1;
                if (self.pots[self.pos][p] == '#') r += 1;
            }
            const yes = self.rules[r];
            if (yes) {
                if (beg > pos) beg = pos;
                if (end < pos) end = pos;
            }
            const p: usize = @intCast(POT_OFFSET + pos);
            self.pots[nxt][p] = if (yes) '#' else '.';
        }
        self.pos = nxt;
        self.beg = beg;
        self.end = end;
    }
};

test "sample" {
    const data =
        \\initial state: #..#.#..##......###...###
        \\
        \\...## => #
        \\..#.. => #
        \\.#... => #
        \\.#.#. => #
        \\.#.## => #
        \\.##.. => #
        \\.#### => #
        \\#.#.# => #
        \\#.### => #
        \\##.#. => #
        \\##.## => #
        \\###.. => #
        \\###.# => #
        \\####. => #
    ;
    std.debug.print("\n", .{});

    var tunnel = Tunnel.init(testing.allocator);
    defer tunnel.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try tunnel.addLine(line);
    }
    // tunnel.show();

    const count = try tunnel.runIterations(20);
    const expected = @as(isize, 325);
    try testing.expectEqual(expected, count);
}
