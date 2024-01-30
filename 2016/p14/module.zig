const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Pad = struct {
    allocator: Allocator,
    stretching: bool,
    sbuf: [100]u8,
    slen: usize,
    where: [16]std.ArrayList(usize),

    pub fn init(allocator: Allocator, stretching: bool) Pad {
        var self = Pad{
            .allocator = allocator,
            .stretching = stretching,
            .sbuf = undefined,
            .slen = 0,
            .where = undefined,
        };
        for (self.where, 0..) |_, p| {
            self.where[p] = std.ArrayList(usize).init(allocator);
        }
        return self;
    }

    pub fn deinit(self: *Pad) void {
        for (self.where, 0..) |_, p| {
            self.where[p].deinit();
        }
    }

    pub fn addLine(self: *Pad, line: []const u8) !void {
        std.mem.copyForwards(u8, &self.sbuf, line);
        self.slen = line.len;
    }

    pub fn getKeyIndex(self: *Pad, wanted_index: usize) !usize {
        var keys = std.ArrayList(usize).init(self.allocator);
        defer keys.deinit();

        var buf: [100]u8 = undefined;
        var index: usize = 0;
        while (keys.items.len < wanted_index) : (index += 1) {
            const hash = try self.getIndexHash(index, &buf);

            var c3: u8 = 0; // only need first 3-char run
            var c5buf: [16]u8 = undefined; // need all 5-char runs
            var c5pos: usize = 0;
            HASH: for (hash, 0..) |c, p| {
                if (p + 3 > hash.len) continue;
                if (c != hash[p + 1]) continue;
                if (c != hash[p + 2]) continue;

                // only need first 3-char run
                if (c3 == 0) c3 = c;

                if (p + 5 > hash.len) continue;
                if (c != hash[p + 3]) continue;
                if (c != hash[p + 4]) continue;

                // need all distinct 5-char runs
                for (0..c5pos) |x| {
                    if (c5buf[x] == c) continue :HASH;
                }
                c5buf[c5pos] = c;
                c5pos += 1;
            }

            // for all 5-char runs, count 3-char previous runs
            for (0..c5pos) |p| {
                const idx = try charToIndex(c5buf[p]);
                for (self.where[idx].items) |w| {
                    if (w + 1000 < index) continue;
                    try keys.append(w);
                }
            }

            // for a 3-char run, remember it
            if (c3 > 0) {
                try self.where[try charToIndex(c3)].append(index);
            }
        }

        // sort all found 3-char runs, and return the one we want
        std.sort.heap(usize, keys.items, {}, std.sort.asc(usize));
        return keys.items[wanted_index - 1];
    }

    fn getIndexHash(self: *Pad, index: usize, buf: []u8) ![]const u8 {
        const salt = self.sbuf[0..self.slen];
        std.mem.copyForwards(u8, buf, salt);
        const num = try std.fmt.bufPrint(buf[salt.len..], "{d}", .{index});
        var blen: usize = salt.len + num.len;
        const rounds: usize = if (self.stretching) 2016 else 0;
        for (0..rounds + 1) |_| {
            const str = buf[0..blen];
            var hash: [std.crypto.hash.Md5.digest_length]u8 = undefined;
            std.crypto.hash.Md5.hash(str, &hash, .{});
            var tmp: [100]u8 = undefined;
            var len: usize = 0;
            for (hash) |h| {
                tmp[len] = try indexToChar(h / 16);
                len += 1;
                tmp[len] = try indexToChar(h % 16);
                len += 1;
            }
            const fmt = tmp[0..len];
            std.mem.copyForwards(u8, buf, fmt);
            blen = len;
        }
        return buf[0..blen];
    }

    fn charToIndex(char: u8) !usize {
        return switch (char) {
            '0'...'9' => |c| c - '0',
            'a'...'z' => |c| c - 'a' + 10,
            'A'...'Z' => |c| c - 'A' + 10,
            else => error.InvalidChar,
        };
    }

    fn indexToChar(index: u8) !u8 {
        return switch (index) {
            0...9 => |i| i + '0',
            10...15 => |i| i - 10 + 'a',
            else => error.InvalidIndex,
        };
    }
};

test "sample part 1" {
    const data =
        \\abc
    ;

    var pad = Pad.init(std.testing.allocator, false);
    defer pad.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try pad.addLine(line);
    }

    const index = try pad.getKeyIndex(64);
    const expected = @as(usize, 22728);
    try testing.expectEqual(expected, index);
}

test "sample part 2" {
    const data =
        \\abc
    ;

    var pad = Pad.init(std.testing.allocator, true);
    defer pad.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try pad.addLine(line);
    }

    const index = try pad.getKeyIndex(64);
    const expected = @as(usize, 22551);
    try testing.expectEqual(expected, index);
}
