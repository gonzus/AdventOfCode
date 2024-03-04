const std = @import("std");
const testing = std.testing;

pub const Message = struct {
    const MAX_COLS = 10;
    const MAX_CHARS = 26;

    most: bool,
    size: usize,
    counts: [MAX_COLS][MAX_CHARS]usize,

    pub fn init(most: bool) Message {
        const self = Message{
            .most = most,
            .size = 0,
            .counts = [_][MAX_CHARS]usize{[_]usize{0} ** MAX_CHARS} ** MAX_COLS,
        };
        return self;
    }

    pub fn addLine(self: *Message, line: []const u8) !void {
        if (self.size == 0) {
            if (line.len >= MAX_COLS) return error.LineTooLong;
            self.size = line.len;
        }
        if (self.size != line.len) return error.InconsistentData;
        for (line, 0..) |char, col| {
            const pos = char - 'a';
            self.counts[col][pos] += 1;
        }
    }

    pub fn findCorrectedMessage(self: Message, buffer: []u8) ![]const u8 {
        for (0..self.size) |col| {
            var best_cnt: usize = if (self.most) 0 else std.math.maxInt(usize);
            var best_pos: u8 = std.math.maxInt(u8);
            for (self.counts[col], 0..) |cnt, pos| {
                if (cnt == 0) continue;
                const skip = if (self.most) best_cnt >= cnt else best_cnt <= cnt;
                if (skip) continue;
                best_cnt = cnt;
                best_pos = @intCast(pos);
            }
            buffer[col] = best_pos + 'a';
        }
        return buffer[0..self.size];
    }
};

test "sample part 1" {
    const data =
        \\eedadn
        \\drvtee
        \\eandsr
        \\raavrd
        \\atevrs
        \\tsrnev
        \\sdttsa
        \\rasrtv
        \\nssdts
        \\ntnada
        \\svetve
        \\tesnvt
        \\vntsnd
        \\vrdear
        \\dvrsen
        \\enarar
    ;

    var message = Message.init(true);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try message.addLine(line);
    }

    var buf: [Message.MAX_COLS]u8 = undefined;
    const corrected = try message.findCorrectedMessage(&buf);
    const expected = "easter";
    try testing.expectEqualStrings(expected, corrected);
}

test "sample part 2" {
    const data =
        \\eedadn
        \\drvtee
        \\eandsr
        \\raavrd
        \\atevrs
        \\tsrnev
        \\sdttsa
        \\rasrtv
        \\nssdts
        \\ntnada
        \\svetve
        \\tesnvt
        \\vntsnd
        \\vrdear
        \\dvrsen
        \\enarar
    ;

    var message = Message.init(false);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try message.addLine(line);
    }

    var buf: [Message.MAX_COLS]u8 = undefined;
    const corrected = try message.findCorrectedMessage(&buf);
    const expected = "advent";
    try testing.expectEqualStrings(expected, corrected);
}
