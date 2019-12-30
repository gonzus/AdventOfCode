const std = @import("std");
const assert = std.debug.assert;

pub const Checksum = struct {
    // TODO: how can I create a collection of strings in zig?
    words: [250][26]u8,
    count: usize,
    maxlen: usize,
    count2: usize,
    count3: usize,

    pub fn init() Checksum {
        const allocator = std.heap.direct_allocator;
        return Checksum{
            .words = undefined,
            .count = 0,
            .maxlen = 0,
            .count2 = 0,
            .count3 = 0,
        };
    }

    pub fn deinit(self: *Checksum) void {}

    pub fn add_word(self: *Checksum, word: []const u8) void {
        std.mem.copy(u8, self.words[self.count][0..], word);
        self.count += 1;
        if (self.maxlen < word.len) self.maxlen = word.len;

        var chars: [26]usize = undefined;
        std.mem.set(usize, chars[0..], 0);
        for (word) |c| {
            const p: usize = c - 'a';
            chars[p] += 1;
        }
        var found2: bool = false;
        var found3: bool = false;
        for (chars) |c| {
            if (c == 2) {
                if (!found2) {
                    found2 = true;
                    self.count2 += 1;
                    // std.debug.warn("WORD [{}] => 2\n", word);
                    continue;
                }
            }
            if (c == 3) {
                if (!found3) {
                    found3 = true;
                    self.count3 += 1;
                    // std.debug.warn("WORD [{}] => 3\n", word);
                    continue;
                }
            }
        }
    }

    pub fn compute_checksum(self: *Checksum) usize {
        return self.count2 * self.count3;
    }

    pub fn find_common_letters(self: *Checksum, buf: *[26]u8) usize {
        var j: usize = 0;
        while (j < self.count) : (j += 1) {
            var k: usize = j + 1;
            while (k < self.count) : (k += 1) {
                var dtot: usize = 0;
                var dpos: usize = 0;
                var l: usize = 0;
                while (l < self.maxlen) : (l += 1) {
                    if (self.words[j][l] == self.words[k][l]) continue;
                    dpos = l;
                    dtot += 1;
                }
                if (dtot != 1) continue;
                // std.debug.warn("MATCH {} = [{}] - [{}]\n", dpos, self.words[j][0..self.maxlen], self.words[k][0..self.maxlen]);
                std.mem.copy(u8, buf[0..], self.words[j][0..dpos]);
                std.mem.copy(u8, buf[dpos..], self.words[k][dpos + 1 ..]);
                return self.maxlen - 1;
            }
        }
        return 0;
    }
};

test "simple checksum" {
    const Data = struct {
        values: []const u8,
        expected: isize,
    };
    const data =
        \\abcdef
        \\bababc
        \\abbcde
        \\abcccd
        \\aabcdd
        \\abcdee
        \\ababab
    ;

    var checksum = Checksum.init();
    defer checksum.deinit();

    var it = std.mem.separate(data, "\n");
    while (it.next()) |line| {
        checksum.add_word(line);
    }
    assert(checksum.compute_checksum() == 12);
}

test "simple common letters" {
    const Data = struct {
        values: []const u8,
        expected: isize,
    };
    const data =
        \\abcde
        \\fghij
        \\klmno
        \\pqrst
        \\fguij
        \\axcye
        \\wvxyz
    ;

    var checksum = Checksum.init();
    defer checksum.deinit();

    var it = std.mem.separate(data, "\n");
    while (it.next()) |line| {
        checksum.add_word(line);
    }
    var buf: [26]u8 = undefined;
    const len = checksum.find_common_letters(&buf);
    // std.debug.warn("MATCH: [{}]\n", buf[0..len]);
    assert(std.mem.compare(u8, buf[0..len], "fgij") == std.mem.Compare.Equal);
}
