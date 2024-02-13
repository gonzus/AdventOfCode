const std = @import("std");
const testing = std.testing;

pub const Stream = struct {
    score: usize,
    garbage: usize,

    pub fn init() Stream {
        return .{
            .score = 0,
            .garbage = 0,
        };
    }

    pub fn deinit(self: *Stream) void {
        _ = self;
    }

    pub fn addLine(self: *Stream, line: []const u8) !void {
        self.score = 0;
        self.garbage = 0;
        const State = enum { text, group, garbage };
        var state: [100]State = undefined;
        var nesting: usize = 0;
        state[nesting] = .text;
        var pos: usize = 0;
        while (pos < line.len) : (pos += 1) {
            const c = line[pos];
            switch (c) {
                '{' => switch (state[nesting]) {
                    .text, .group => {
                        nesting += 1;
                        state[nesting] = .group;
                    },
                    .garbage => {
                        self.garbage += 1;
                    },
                },
                '}' => switch (state[nesting]) {
                    .text => {
                        return error.InvalidEndOfGroup;
                    },
                    .group => {
                        self.score += nesting;
                        nesting -= 1;
                    },
                    .garbage => {
                        self.garbage += 1;
                    },
                },
                '<' => switch (state[nesting]) {
                    .text, .group => {
                        nesting += 1;
                        state[nesting] = .garbage;
                    },
                    .garbage => {
                        self.garbage += 1;
                    },
                },
                '>' => switch (state[nesting]) {
                    .text, .group => {
                        return error.InvalidEndOfGarbage;
                    },
                    .garbage => {
                        nesting -= 1;
                    },
                },
                '!' => switch (state[nesting]) {
                    .text, .group => {},
                    .garbage => pos += 1,
                },
                else => switch (state[nesting]) {
                    .text, .group => {},
                    .garbage => self.garbage += 1,
                },
            }
        }
        std.debug.assert(nesting == 0);
    }

    pub fn getTotalScore(self: Stream) !usize {
        return self.score;
    }

    pub fn getNonCanceledCharacters(self: Stream) !usize {
        return self.garbage;
    }
};

test "sample part 1 case A" {
    const data =
        \\{}
    ;

    var stream = Stream.init();
    defer stream.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stream.addLine(line);
    }

    const score = try stream.getTotalScore();
    const expected = @as(usize, 1);
    try testing.expectEqual(expected, score);
}

test "sample part 1 case B" {
    const data =
        \\{{{}}}
    ;

    var stream = Stream.init();
    defer stream.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stream.addLine(line);
    }

    const score = try stream.getTotalScore();
    const expected = @as(usize, 6);
    try testing.expectEqual(expected, score);
}

test "sample part 1 case C" {
    const data =
        \\{{},{}}
    ;

    var stream = Stream.init();
    defer stream.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stream.addLine(line);
    }

    const score = try stream.getTotalScore();
    const expected = @as(usize, 5);
    try testing.expectEqual(expected, score);
}

test "sample part 1 case D" {
    const data =
        \\{{{},{},{{}}}}
    ;

    var stream = Stream.init();
    defer stream.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stream.addLine(line);
    }

    const score = try stream.getTotalScore();
    const expected = @as(usize, 16);
    try testing.expectEqual(expected, score);
}

test "sample part 1 case E" {
    const data =
        \\{<a>,<a>,<a>,<a>}
    ;

    var stream = Stream.init();
    defer stream.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stream.addLine(line);
    }

    const score = try stream.getTotalScore();
    const expected = @as(usize, 1);
    try testing.expectEqual(expected, score);
}

test "sample part 1 case F" {
    const data =
        \\{{<ab>},{<ab>},{<ab>},{<ab>}}
    ;

    var stream = Stream.init();
    defer stream.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stream.addLine(line);
    }

    const score = try stream.getTotalScore();
    const expected = @as(usize, 9);
    try testing.expectEqual(expected, score);
}

test "sample part 1 case G" {
    const data =
        \\{{<!!>},{<!!>},{<!!>},{<!!>}}
    ;

    var stream = Stream.init();
    defer stream.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stream.addLine(line);
    }

    const score = try stream.getTotalScore();
    const expected = @as(usize, 9);
    try testing.expectEqual(expected, score);
}

test "sample part 1 case H" {
    const data =
        \\{{<a!>},{<a!>},{<a!>},{<ab>}}
    ;

    var stream = Stream.init();
    defer stream.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stream.addLine(line);
    }

    const score = try stream.getTotalScore();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, score);
}

test "sample part 2 case A" {
    const data =
        \\<>
    ;

    var stream = Stream.init();
    defer stream.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stream.addLine(line);
    }

    const score = try stream.getNonCanceledCharacters();
    const expected = @as(usize, 0);
    try testing.expectEqual(expected, score);
}

test "sample part 2 case B" {
    const data =
        \\<random characters>
    ;

    var stream = Stream.init();
    defer stream.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stream.addLine(line);
    }

    const score = try stream.getNonCanceledCharacters();
    const expected = @as(usize, 17);
    try testing.expectEqual(expected, score);
}

test "sample part 2 case C" {
    const data =
        \\<<<<>
    ;

    var stream = Stream.init();
    defer stream.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stream.addLine(line);
    }

    const score = try stream.getNonCanceledCharacters();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, score);
}

test "sample part 2 case D" {
    const data =
        \\<{!>}>
    ;

    var stream = Stream.init();
    defer stream.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stream.addLine(line);
    }

    const score = try stream.getNonCanceledCharacters();
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, score);
}

test "sample part 2 case E" {
    const data =
        \\<!!>
    ;

    var stream = Stream.init();
    defer stream.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stream.addLine(line);
    }

    const score = try stream.getNonCanceledCharacters();
    const expected = @as(usize, 0);
    try testing.expectEqual(expected, score);
}

test "sample part 2 case F" {
    const data =
        \\<!!!>>
    ;

    var stream = Stream.init();
    defer stream.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stream.addLine(line);
    }

    const score = try stream.getNonCanceledCharacters();
    const expected = @as(usize, 0);
    try testing.expectEqual(expected, score);
}

test "sample part 2 case G" {
    const data =
        \\<{o"i!a,<{i<a>
    ;

    var stream = Stream.init();
    defer stream.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try stream.addLine(line);
    }

    const score = try stream.getNonCanceledCharacters();
    const expected = @as(usize, 10);
    try testing.expectEqual(expected, score);
}
