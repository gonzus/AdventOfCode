const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Calibration = struct {
    only_digits: bool,
    sum: usize,
    digits: std.ArrayList(usize),

    pub fn init(allocator: Allocator, only_digits: bool) Calibration {
        var self = Calibration{
            .only_digits = only_digits,
            .sum = 0,
            .digits = std.ArrayList(usize).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Calibration) void {
        self.digits.deinit();
    }

    pub fn getSum(self: Calibration) usize {
        return self.sum;
    }

    pub fn addLine(self: *Calibration, line: []const u8) !void {
        const numbers = [_][]const u8{
            "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
        };

        self.digits.clearRetainingCapacity();
        for (line, 0..) |char, pos| {
            if (std.ascii.isDigit(char)) {
                const digit = char - '0';
                try self.digits.append(digit);
                continue;
            }

            if (self.only_digits) {
                continue;
            }

            const left = line.len - pos;
            for (numbers, 0..) |number, digit| {
                if (left >= number.len and std.mem.eql(u8, line[pos .. pos + number.len], number)) {
                    try self.digits.append(digit);
                    break;
                }
            }
        }

        const digits = self.digits.items;
        if (digits.len <= 0) unreachable;
        const value = digits[0] * 10 + digits[digits.len - 1];
        self.sum += value;
    }
};

test "sample part 1" {
    const data =
        \\1abc2
        \\pqr3stu8vwx
        \\a1b2c3d4e5f
        \\treb7uchet
    ;

    var calibration = Calibration.init(std.testing.allocator, true);
    defer calibration.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try calibration.addLine(line);
    }

    const sum = calibration.getSum();
    const expected = @as(usize, 142);
    try testing.expectEqual(expected, sum);
}

test "sample part 2" {
    const data =
        \\two1nine
        \\eightwothree
        \\abcone2threexyz
        \\xtwone3four
        \\4nineeightseven2
        \\zoneight234
        \\7pqrstsixteen
    ;

    var calibration = Calibration.init(std.testing.allocator, false);
    defer calibration.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try calibration.addLine(line);
    }

    const sum = calibration.getSum();
    const expected = @as(usize, 281);
    try testing.expectEqual(expected, sum);
}
