const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const Display = struct {
    const MAX_DIGIT = 10;
    const MAX_SEGMENT = 7;

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

    count_unique: [MAX_DIGIT]usize,
    mask: [MAX_SEGMENT]u8,
    total_sum: usize,

    pub fn init() Display {
        var self = Display{
            .count_unique = [_]usize{0} ** MAX_DIGIT,
            .mask = [_]u8{0} ** MAX_SEGMENT,
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

                var mapping: [MAX_SEGMENT]u8 = [_]u8{0} ** MAX_SEGMENT;
                for (self.mask) |m, j| {
                    // std.debug.warn("MASK {}: {b:0>7}\n", .{ j, m });
                    const c = @ctz(usize, m);
                    mapping[MAX_SEGMENT - 1 - c] = @as(u8, 1) << @intCast(u3, MAX_SEGMENT - 1 - j);
                }

                var itd = std.mem.tokenize(u8, str, " ");
                var value: usize = 0;
                while (itd.next()) |segments| {
                    self.update_unique_counts(segments);

                    var mask: u8 = 0;
                    for (segments) |s| {
                        mask |= mapping[s - 'a'];
                    }
                    const digit = self.mask_to_digit(mask);
                    value = value * MAX_DIGIT + digit;
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
        for (self.mask) |_, j| {
            self.mask[j] = 0b1111111;
        }
    }

    fn build_mask_for_segments(_: Display, segments: []const u8) u8 {
        var mask: u8 = 0;
        for (segments) |s| {
            const shift = @intCast(u3, MAX_SEGMENT - 1 - (s - 'a'));
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
        if (len == 2) {
            self.restric_single_mask('c', possible);
            self.restric_single_mask('f', possible);
            return;
        }
        if (len == 3) {
            self.restric_single_mask('a', possible);
            self.restric_single_mask('c', possible);
            self.restric_single_mask('f', possible);
            return;
        }
        if (len == 4) {
            self.restric_single_mask('b', possible);
            self.restric_single_mask('c', possible);
            self.restric_single_mask('d', possible);
            self.restric_single_mask('f', possible);
            return;
        }
        if (len == 5) {
            self.restric_single_mask('a', possible);
            self.restric_single_mask('d', possible);
            self.restric_single_mask('g', possible);
            return;
        }
        if (len == 6) {
            self.restric_single_mask('a', possible);
            self.restric_single_mask('b', possible);
            self.restric_single_mask('f', possible);
            self.restric_single_mask('g', possible);
            return;
        }
        if (len == 7) {
            self.restric_single_mask('a', possible);
            self.restric_single_mask('b', possible);
            self.restric_single_mask('c', possible);
            self.restric_single_mask('d', possible);
            self.restric_single_mask('e', possible);
            self.restric_single_mask('f', possible);
            self.restric_single_mask('g', possible);
            return;
        }
        unreachable;
    }

    fn propagate_masks(self: *Display) void {
        while (true) {
            var changed: usize = 0;
            var j: usize = 0;
            while (j < MAX_SEGMENT) : (j += 1) {
                const mj = self.mask[j];
                if (@popCount(usize, mj) != 1) continue;
                var k: usize = 0;
                while (k < MAX_SEGMENT) : (k += 1) {
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
        if (mask == 0b1110111) {
            return 0;
        }
        if (mask == 0b1101111) {
            return 6;
        }
        if (mask == 0b1111011) {
            return 9;
        }
        if (mask == 0b0010010) {
            return 1;
        }
        if (mask == 0b1011101) {
            return 2;
        }
        if (mask == 0b1011011) {
            return 3;
        }
        if (mask == 0b1101011) {
            return 5;
        }
        if (mask == 0b0111010) {
            return 4;
        }
        if (mask == 0b1010010) {
            return 7;
        }
        if (mask == 0b1111111) {
            return 8;
        }
        unreachable;
    }

    fn update_unique_counts(self: *Display, segments: []const u8) void {
        const len = segments.len;
        if (len == 2) {
            self.count_unique[1] += 1;
            return;
        }
        if (len == 3) {
            self.count_unique[7] += 1;
            return;
        }
        if (len == 4) {
            self.count_unique[4] += 1;
            return;
        }
        if (len == 7) {
            self.count_unique[8] += 1;
            return;
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
