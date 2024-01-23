const std = @import("std");
const testing = std.testing;

pub const Message = struct {
    recursive: bool,
    length: usize,

    pub fn init(recursive: bool) Message {
        return Message{
            .recursive = recursive,
            .length = 0,
        };
    }

    pub fn addLine(self: *Message, line: []const u8) !void {
        self.length += self.expandAndCount(0, line);
    }

    pub fn getExpandedLength(self: Message) !usize {
        return self.length;
    }

    fn expandAndCount(self: Message, level: usize, str: []const u8) usize {
        // std.debug.print("<{}> STR [{s}]\n", .{ level, str });
        var length: usize = 0;
        const State = enum { data, str_len, str_cnt };
        var state = State.data;
        var str_len: usize = 0;
        var str_cnt: usize = 0;
        var beg: usize = 0;
        var pos: usize = 0;
        while (pos < str.len) : (pos += 1) {
            const chr = str[pos];
            switch (chr) {
                '(' => switch (state) {
                    .data => {
                        beg = pos;
                        state = .str_len;
                        str_len = 0;
                    },
                    .str_len, .str_cnt => {
                        state = .data;
                        length += pos - beg;
                    },
                },
                'x' => switch (state) {
                    .data => length += 1,
                    .str_len => {
                        state = .str_cnt;
                        str_cnt = 0;
                    },
                    .str_cnt => {
                        state = .data;
                        length += pos - beg;
                    },
                },
                '0'...'9' => |c| switch (state) {
                    .data => length += 1,
                    .str_len => {
                        str_len *= 10;
                        str_len += c - '0';
                    },
                    .str_cnt => {
                        str_cnt *= 10;
                        str_cnt += c - '0';
                    },
                },
                ')' => switch (state) {
                    .data => length += 1,
                    .str_len => {
                        state = .data;
                        length += pos - beg;
                    },
                    .str_cnt => {
                        var len: usize = str_len;
                        if (self.recursive) {
                            const sub = str[pos + 1 .. pos + 1 + len];
                            len = self.expandAndCount(level + 1, sub);
                        }
                        length += len * str_cnt;
                        pos += str_len;
                        state = .data;
                    },
                },
                else => switch (state) {
                    .data => length += 1,
                    .str_len, .str_cnt => {
                        state = .data;
                        length += pos - beg;
                    },
                },
            }
        }
        return length;
    }
};

test "sample part 1" {
    const data =
        \\ADVENT
        \\A(1x5)BC
        \\(3x3)XYZ
        \\A(2x2)BCD(2x2)EFG
        \\(6x1)(1x3)A
        \\X(8x2)(3x3)ABCY
    ;

    var message = Message.init(false);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try message.addLine(line);
    }

    const length = try message.getExpandedLength();
    const expected = @as(usize, 6 + 7 + 9 + 11 + 6 + 18);
    try testing.expectEqual(expected, length);
}

test "sample part 2" {
    const data =
        \\(3x3)XYZ
        \\X(8x2)(3x3)ABCY
        \\(27x12)(20x12)(13x14)(7x10)(1x12)A
        \\(25x3)(3x3)ABC(2x3)XY(5x2)PQRSTX(18x9)(3x2)TWO(5x7)SEVEN
    ;

    var message = Message.init(true);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try message.addLine(line);
    }

    const length = try message.getExpandedLength();
    const expected = @as(usize, 9 + 20 + 241920 + 445);
    try testing.expectEqual(expected, length);
}
