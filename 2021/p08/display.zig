const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const Display = struct {
    // digit  segments  length  digits with same length
    // -----  --------  ------  -----------------------
    //     0  abc.efg   6       0, 6, 9
    //     6  ab.defg   6       0, 6, 9
    //     9  abcd.fg   6       0, 6, 9
    //     1  ..c..f.   2       1
    //     2  a.cde.g   5       2, 3, 5
    //     3  a.cd.fg   5       2, 3, 5
    //     5  ab.d.fg   5       2, 3, 5
    //     4  .bcd.f.   4       4
    //     7  a.c..f.   3       7
    //     8  abcdefg   7       8

    const NUM_DIGITS = 10;
    const NUM_SEGMENTS = 7;

    // Given the length of a set of segments, determine which unique digit
    // could be mapped by that segment length.  A zero value indicates either
    // no digits or more than one digit, so digits are non-unique for that
    // length.
    //
    // Example: a set of 3 segments can only denote a 7 digit.
    const digits_for_len = [NUM_SEGMENTS + 1]u8{
        0, // 0
        0, // 1
        1, // 2
        7, // 3
        4, // 4
        0, // 5
        0, // 6
        8, // 7
    };

    // Given the length of a set of segments, determine which segments are
    // definitely part of all the digits that could be mapped to that segment
    // length.
    //
    // Example: a set of 5 segments could correspond to a 2, 3 or 4 digit; the
    // segments that are shared by all of those digits are 'a', 'd' and 'g'.
    const segments_for_len = [NUM_SEGMENTS + 1][]const u8{
        "", // 0
        "", // 1
        "cf", // 2
        "acf", // 3
        "bcdf", // 4
        "adg", // 5
        "abfg", // 6
        "abcdefg", // 7
    };

    // For each digit, the corresponding mask has a 1 if that digit uses that
    // given segment in the display.
    // Example: digit 7 uses segments 'a', 'c' & 'f'.
    const digit_mask = [NUM_DIGITS]u8{
        0b1110111, // 0
        0b0010010, // 1
        0b1011101, // 2
        0b1011011, // 3
        0b0111010, // 4
        0b1101011, // 5
        0b1101111, // 6
        0b1010010, // 7
        0b1111111, // 8
        0b1111011, // 9
    };

    count_unique: [NUM_DIGITS]usize,
    mask: [NUM_SEGMENTS]u8,
    total_sum: usize,

    pub fn init() Display {
        var self = Display{
            .count_unique = [_]usize{0} ** NUM_DIGITS,
            .mask = [_]u8{0} ** NUM_SEGMENTS,
            .total_sum = 0,
        };

        return self;
    }

    pub fn deinit(_: *Display) void {}

    pub fn process_line(self: *Display, data: []const u8) void {
        var pos: usize = 0;
        var ita = std.mem.split(u8, data, " | ");
        while (ita.next()) |str| : (pos += 1) {
            if (pos == 0) {
                self.init_masks();

                var itd = std.mem.tokenize(u8, str, " ");
                while (itd.next()) |segments| {
                    self.restrict_masks(segments);
                }

                continue;
            }
            if (pos == 1) {
                self.propagate_masks();

                var mapping: [NUM_SEGMENTS]u8 = [_]u8{0} ** NUM_SEGMENTS;
                for (self.mask) |m, j| {
                    // std.debug.warn("MASK {}: {b:0>7}\n", .{ j, m });
                    const c = @ctz(usize, m);
                    mapping[NUM_SEGMENTS - 1 - c] = @as(u8, 1) << @intCast(u3, NUM_SEGMENTS - 1 - j);
                }

                var itd = std.mem.tokenize(u8, str, " ");
                var value: usize = 0;
                while (itd.next()) |segments| {
                    self.update_unique_counts(segments);

                    var mask: u8 = 0;
                    for (segments) |segment| {
                        mask |= mapping[segment - 'a'];
                    }
                    const digit = self.mask_to_digit(mask);
                    value = value * NUM_DIGITS + digit;
                }

                self.total_sum += value;
                continue;
            }
            unreachable;
        }
    }

    pub fn count_unique_digits(self: Display) usize {
        var total: usize = 0;
        for (self.count_unique) |c| {
            total += c;
        }
        return total;
    }

    pub fn get_total_sum(self: Display) usize {
        return self.total_sum;
    }

    fn init_masks(self: *Display) void {
        const mask = (1 << NUM_SEGMENTS) - 1;
        for (self.mask) |_, j| {
            self.mask[j] = mask;
        }
    }

    fn build_mask_for_segments(_: Display, segments: []const u8) u8 {
        var mask: u8 = 0;
        for (segments) |segment| {
            const shift = @intCast(u3, NUM_SEGMENTS - 1 - (segment - 'a'));
            const bit = @as(u8, 1) << shift;
            mask |= bit;
        }
        return mask;
    }

    fn restric_single_mask(self: *Display, segment: u8, possible: u8) void {
        const pos = segment - 'a';
        self.mask[pos] &= possible;
    }

    fn restrict_masks(self: *Display, segments: []const u8) void {
        const possible = self.build_mask_for_segments(segments);
        const len = segments.len;
        if (len >= 0 and len <= NUM_SEGMENTS) {
            for (segments_for_len[len]) |segment| {
                self.restric_single_mask(segment, possible);
            }
        }
    }

    fn propagate_masks(self: *Display) void {
        while (true) {
            var changed: usize = 0;
            var j: usize = 0;
            while (j < NUM_SEGMENTS) : (j += 1) {
                const mj = self.mask[j];
                if (@popCount(usize, mj) != 1) continue;
                var k: usize = 0;
                while (k < NUM_SEGMENTS) : (k += 1) {
                    if (k == j) continue;
                    const mk = self.mask[k];
                    if (@popCount(usize, mk) == 1) continue;
                    self.mask[k] &= ~mj;
                    changed += 1;
                }
            }
            if (changed == 0) break;
        }
    }

    fn mask_to_digit(_: Display, mask: u8) u8 {
        // TODO: this would be better with a hash, but the array only has 10
        // entries, so we just do a linear search on it.
        for (digit_mask) |m, p| {
            if (mask == m) return @intCast(u8, p);
        }
        unreachable;
    }

    fn update_unique_counts(self: *Display, segments: []const u8) void {
        const len = segments.len;
        if (len >= 0 and len <= NUM_SEGMENTS) {
            const d = digits_for_len[len];
            if (d > 0) {
                self.count_unique[d] += 1;
            }
        }
    }
};

test "sample part a" {
    const data: []const u8 =
        \\be cfbegad cbdgef fgaecd cgeb fdcge agebfd fecdb fabcd edb | fdgacbe cefdb cefbgd gcbe
        \\edbfga begcd cbg gc gcadebf fbgde acbgfd abcde gfcbed gfec | fcgedb cgb dgebacf gc
        \\fgaebd cg bdaec gdafb agbcfd gdcbef bgcad gfac gcb cdgabef | cg cg fdcagb cbg
        \\fbegcd cbd adcefb dageb afcb bc aefdc ecdab fgdeca fcdbega | efabcd cedba gadfec cb
        \\aecbfdg fbg gf bafeg dbefa fcge gcbea fcaegb dgceab fcbdga | gecf egdcabf bgf bfgea
        \\fgeab ca afcebg bdacfeg cfaedg gcfdb baec bfadeg bafgc acf | gebdcfa ecba ca fadegcb
        \\dbcfg fgd bdegcaf fgec aegbdf ecdfab fbedc dacgb gdcebf gf | cefg dcbef fcge gbcadfe
        \\bdfegc cbegaf gecbf dfcage bdacg ed bedf ced adcbefg gebcd | ed bcgafe cdgba cbgef
        \\egadfb cdbfeg cegd fecab cgb gbdefca cg fgcdab egfdb bfceg | gbdfcae bgc cg cgb
        \\gcafb gcf dcaebfg ecagb gf abcdeg gaef cafbge fdbac fegbdc | fgae cfgab fg bagce
    ;

    var display = Display.init();
    defer display.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        display.process_line(line);
    }
    const unique = display.count_unique_digits();
    try testing.expect(unique == 26);
}

test "sample part b" {
    const data: []const u8 =
        \\be cfbegad cbdgef fgaecd cgeb fdcge agebfd fecdb fabcd edb | fdgacbe cefdb cefbgd gcbe
        \\edbfga begcd cbg gc gcadebf fbgde acbgfd abcde gfcbed gfec | fcgedb cgb dgebacf gc
        \\fgaebd cg bdaec gdafb agbcfd gdcbef bgcad gfac gcb cdgabef | cg cg fdcagb cbg
        \\fbegcd cbd adcefb dageb afcb bc aefdc ecdab fgdeca fcdbega | efabcd cedba gadfec cb
        \\aecbfdg fbg gf bafeg dbefa fcge gcbea fcaegb dgceab fcbdga | gecf egdcabf bgf bfgea
        \\fgeab ca afcebg bdacfeg cfaedg gcfdb baec bfadeg bafgc acf | gebdcfa ecba ca fadegcb
        \\dbcfg fgd bdegcaf fgec aegbdf ecdfab fbedc dacgb gdcebf gf | cefg dcbef fcge gbcadfe
        \\bdfegc cbegaf gecbf dfcage bdacg ed bedf ced adcbefg gebcd | ed bcgafe cdgba cbgef
        \\egadfb cdbfeg cegd fecab cgb gbdefca cg fgcdab egfdb bfceg | gbdfcae bgc cg cgb
        \\gcafb gcf dcaebfg ecagb gf abcdeg gaef cafbge fdbac fegbdc | fgae cfgab fg bagce
    ;

    var display = Display.init();
    defer display.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        display.process_line(line);
    }
    const total_sum = display.get_total_sum();
    try testing.expect(total_sum == 61229);
}
