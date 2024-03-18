const std = @import("std");
const testing = std.testing;

pub const Polymer = struct {
    const SIZE = 51000;

    buf: [2][SIZE]u8,
    txt: [2][]const u8,
    cur: usize,

    pub fn init() Polymer {
        return .{
            .buf = undefined,
            .txt = [_][]const u8{""} ** 2,
            .cur = 0,
        };
    }

    pub fn addLine(self: *Polymer, line: []const u8) !void {
        std.mem.copyForwards(u8, &self.buf[self.cur], line);
        self.txt[self.cur] = self.buf[self.cur][0..line.len];
    }

    pub fn fullyReact(self: *Polymer) !usize {
        var nxt: usize = 1 - self.cur;
        self.txt[nxt] = "";
        while (self.txt[self.cur].len != self.txt[nxt].len) {
            var p: usize = 0;
            var q: usize = 0;
            while (p < self.txt[self.cur].len) : (p += 1) {
                if (p < self.txt[self.cur].len - 1) {
                    const c0 = self.txt[self.cur][p + 0];
                    const c1 = self.txt[self.cur][p + 1];
                    if (c1 != c0 and (std.ascii.toUpper(c1) == c0 or std.ascii.toUpper(c0) == c1)) {
                        p += 1;
                        continue;
                    }
                }
                self.buf[nxt][q] = self.txt[self.cur][p];
                q += 1;
            }
            self.txt[nxt] = self.buf[nxt][0..q];
            self.cur = nxt;
            nxt = 1 - nxt;
        }
        return self.txt[self.cur].len;
    }

    pub fn findLargestBlocker(self: *Polymer) !usize {
        _ = try self.fullyReact();

        var best: usize = std.math.maxInt(usize);
        var tmp: [SIZE]u8 = undefined;
        var len: usize = 0;
        std.mem.copyForwards(u8, &tmp, self.txt[self.cur]);
        len = self.txt[self.cur].len;
        for (0..26) |j| {
            const r = 'a' + j;
            const R = 'A' + j;
            var q: usize = 0;
            for (tmp[0..len]) |c| {
                if (c == r or c == R) continue;
                self.buf[self.cur][q] = c;
                q += 1;
            }
            self.txt[self.cur] = self.buf[self.cur][0..q];
            const l = try self.fullyReact();
            if (best > l) best = l;
        }
        std.mem.copyForwards(u8, &self.buf[self.cur], tmp[0..len]);
        self.txt[self.cur] = self.buf[self.cur][0..len];
        return best;
    }
};

test "sample part 1" {
    const data =
        \\dabAcCaCBAcCcaDA
    ;

    var polymer = Polymer.init();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try polymer.addLine(line);
    }
    const length = try polymer.fullyReact();
    const expected = @as(usize, 10);
    try testing.expectEqual(expected, length);
}

test "sample part 2" {
    const data =
        \\dabAcCaCBAcCcaDA
    ;

    var polymer = Polymer.init();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try polymer.addLine(line);
    }
    const length = try polymer.findLargestBlocker();
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, length);
}
