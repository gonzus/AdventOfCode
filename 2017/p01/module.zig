const std = @import("std");
const testing = std.testing;

pub const Captcha = struct {
    halfway: bool,
    sum: usize,

    pub fn init(halfway: bool) Captcha {
        return .{
            .halfway = halfway,
            .sum = 0,
        };
    }

    pub fn addLine(self: *Captcha, line: []const u8) !void {
        const delta: usize = if (self.halfway) line.len / 2 else 1;
        for (line, 0..) |c, p| {
            const n = (p + delta) % line.len;
            if (c != line[n]) continue;
            self.sum += c - '0';
        }
    }

    pub fn getSolution(self: Captcha) usize {
        return self.sum;
    }
};

test "sample part 1 case A" {
    const data =
        \\1122
    ;

    var captcha = Captcha.init(false);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try captcha.addLine(line);
    }

    const distance = captcha.getSolution();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, distance);
}

test "sample part 1 case B" {
    const data =
        \\1111
    ;

    var captcha = Captcha.init(false);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try captcha.addLine(line);
    }

    const distance = captcha.getSolution();
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, distance);
}

test "sample part 1 case C" {
    const data =
        \\1234
    ;

    var captcha = Captcha.init(false);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try captcha.addLine(line);
    }

    const distance = captcha.getSolution();
    const expected = @as(usize, 0);
    try testing.expectEqual(expected, distance);
}

test "sample part 1 case D" {
    const data =
        \\91212129
    ;

    var captcha = Captcha.init(false);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try captcha.addLine(line);
    }

    const distance = captcha.getSolution();
    const expected = @as(usize, 9);
    try testing.expectEqual(expected, distance);
}

test "sample part 2 case A" {
    const data =
        \\1212
    ;

    var captcha = Captcha.init(true);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try captcha.addLine(line);
    }

    const distance = captcha.getSolution();
    const expected = @as(usize, 6);
    try testing.expectEqual(expected, distance);
}

test "sample part 2 case B" {
    const data =
        \\1221
    ;

    var captcha = Captcha.init(true);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try captcha.addLine(line);
    }

    const distance = captcha.getSolution();
    const expected = @as(usize, 0);
    try testing.expectEqual(expected, distance);
}

test "sample part 2 case C" {
    const data =
        \\123425
    ;

    var captcha = Captcha.init(true);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try captcha.addLine(line);
    }

    const distance = captcha.getSolution();
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, distance);
}

test "sample part 2 case D" {
    const data =
        \\123123
    ;

    var captcha = Captcha.init(true);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try captcha.addLine(line);
    }

    const distance = captcha.getSolution();
    const expected = @as(usize, 12);
    try testing.expectEqual(expected, distance);
}

test "sample part 2 case E" {
    const data =
        \\12131415
    ;

    var captcha = Captcha.init(true);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try captcha.addLine(line);
    }

    const distance = captcha.getSolution();
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, distance);
}
