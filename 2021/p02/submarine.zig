const std = @import("std");
const testing = std.testing;

const allocator = std.testing.allocator;

pub const Submarine = struct {
    pub const Mode = enum {
        Simple,
        Complex,
    };

    mode: Mode,
    xpos: usize,
    depth: usize,
    aim: usize,

    pub fn init(mode: Mode) Submarine {
        var self = Submarine{
            .mode = mode,
            .xpos = 0,
            .depth = 0,
            .aim = 0,
        };
        return self;
    }

    pub fn deinit(self: *Submarine) void {
        _ = self;
    }

    pub fn process_command(self: *Submarine, line: []const u8) void {
        var it = std.mem.tokenize(u8, line, " ");
        const c = it.next().?;
        const n = std.fmt.parseInt(usize, it.next().?, 10) catch unreachable;
        if (std.mem.eql(u8, c, "forward")) {
            switch (self.mode) {
                Mode.Simple => {
                    self.xpos += n;
                },
                Mode.Complex => {
                    self.xpos += n;
                    self.depth += n * self.aim;
                },
            }
            return;
        }
        if (std.mem.eql(u8, c, "down")) {
            switch (self.mode) {
                Mode.Simple => {
                    self.depth += n;
                },
                Mode.Complex => {
                    self.aim += n;
                },
            }
            return;
        }
        if (std.mem.eql(u8, c, "up")) {
            switch (self.mode) {
                Mode.Simple => {
                    self.depth -= n;
                },
                Mode.Complex => {
                    self.aim -= n;
                },
            }
            return;
        }
        unreachable;
    }

    pub fn get_position(self: *Submarine) usize {
        return self.xpos * self.depth;
    }
};

test "sample part a" {
    const data: []const u8 =
        \\forward 5
        \\down 5
        \\forward 8
        \\up 3
        \\down 8
        \\forward 2
    ;

    var submarine = Submarine.init(Submarine.Mode.Simple);
    defer submarine.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        submarine.process_command(line);
    }

    const pos = submarine.get_position();
    try testing.expect(pos == 150);
}

test "sample part b" {
    const data: []const u8 =
        \\forward 5
        \\down 5
        \\forward 8
        \\up 3
        \\down 8
        \\forward 2
    ;

    var submarine = Submarine.init(Submarine.Mode.Complex);
    defer submarine.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        submarine.process_command(line);
    }

    const pos = submarine.get_position();
    try testing.expect(pos == 900);
}
