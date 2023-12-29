const std = @import("std");
const testing = std.testing;

pub const Text = struct {
    original: usize,
    effective: usize,
    encoded: usize,

    pub fn init() Text {
        const self = Text{
            .original = 0,
            .effective = 0,
            .encoded = 0,
        };
        return self;
    }

    pub fn deinit(_: *Text) void {}

    pub fn addLine(self: *Text, line: []const u8) !void {
        const State = enum { Normal, Backslash, Hexa1, Hexa2 };
        var state = State.Normal;
        self.encoded += 2; // quotes around content: "..."
        for (line, 0..) |c, p| {
            switch (c) {
                '\\' => switch (state) {
                    .Normal => {
                        self.original += 1;
                        self.encoded += 2;
                        state = .Backslash;
                    },
                    .Backslash => {
                        self.original += 1;
                        self.effective += 1;
                        self.encoded += 2;
                        state = .Normal;
                    },
                    .Hexa1, .Hexa2 => {
                        return error.BadSyntax;
                    },
                },
                '"' => switch (state) {
                    .Normal => {
                        if (p == 0 or p == line.len - 1) {
                            self.original += 1;
                            self.encoded += 2;
                        } else {
                            return error.BadSyntax;
                        }
                    },
                    .Backslash => {
                        self.original += 1;
                        self.effective += 1;
                        self.encoded += 2;
                        state = .Normal;
                    },
                    .Hexa1, .Hexa2 => {
                        return error.BadSyntax;
                    },
                },
                'x' => switch (state) {
                    .Normal => {
                        self.original += 1;
                        self.effective += 1;
                        self.encoded += 1;
                    },
                    .Backslash => {
                        self.original += 1;
                        self.encoded += 1;
                        state = .Hexa1;
                    },
                    .Hexa1, .Hexa2 => {
                        return error.BadSyntax;
                    },
                },
                '0'...'9', 'a'...'f', 'A'...'F' => switch (state) {
                    .Normal => {
                        self.original += 1;
                        self.encoded += 1;
                        self.effective += 1;
                    },
                    .Backslash => {
                        return error.BadSyntax;
                    },
                    .Hexa1 => {
                        self.original += 1;
                        self.encoded += 1;
                        state = .Hexa2;
                    },
                    .Hexa2 => {
                        self.original += 1;
                        self.effective += 1;
                        self.encoded += 1;
                        state = .Normal;
                    },
                },
                else => switch (state) {
                    .Normal => {
                        self.original += 1;
                        self.effective += 1;
                        self.encoded += 1;
                    },
                    .Backslash, .Hexa1, .Hexa2 => {
                        return error.BadSyntax;
                    },
                },
            }
        }
    }

    pub fn getEffectiveCharacterCount(self: Text) usize {
        return self.original - self.effective;
    }

    pub fn getEncodedCharacterCount(self: Text) usize {
        return self.encoded - self.original;
    }
};

test "sample part 1" {
    const data =
        \\""
        \\"abc"
        \\"aaa\"aaa"
        \\"\x27"
    ;

    var text = Text.init();
    defer text.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try text.addLine(line);
    }

    const effective = text.getEffectiveCharacterCount();
    const expected = @as(usize, 23 - 11);
    try testing.expectEqual(expected, effective);
}

test "sample part 2" {
    const data =
        \\""
        \\"abc"
        \\"aaa\"aaa"
        \\"\x27"
    ;

    var text = Text.init();
    defer text.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try text.addLine(line);
    }

    const effective = text.getEncodedCharacterCount();
    const expected = @as(usize, 42 - 23);
    try testing.expectEqual(expected, effective);
}
