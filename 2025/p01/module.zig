const std = @import("std");
const testing = std.testing;

pub const Module = struct {
    const SIZE = 100;
    const START = 50;
    const Dir = enum(u8) { L = 'L', R = 'R' };

    use_CLICK: bool,
    current: u8,
    zeros: usize,

    pub fn init(use_CLICK: bool) Module {
        return .{
            // 0x434C49434B in ASCII is CLICK
            .use_CLICK = use_CLICK,
            .current = START,
            .zeros = 0,
        };
    }

    pub fn deinit(_: *Module) void {}

    pub fn parseInput(self: *Module, data: []const u8) !void {
        var it_lines = std.mem.splitScalar(u8, data, '\n');
        while (it_lines.next()) |line| {
            const dir: Dir = @enumFromInt(line[0]);
            var num = try std.fmt.parseUnsigned(usize, line[1..], 10);
            if (self.use_CLICK) {
                self.zeros += num / SIZE;
            }
            num %= SIZE;
            const use_CLICK = self.use_CLICK and self.current > 0;
            switch (dir) {
                .L => {
                    if (use_CLICK and self.current < num) self.zeros += 1;
                    self.current += SIZE;
                    self.current -= @intCast(num);
                },
                .R => {
                    if (use_CLICK and self.current + num > SIZE) self.zeros += 1;
                    self.current += @intCast(num);
                },
            }
            self.current %= SIZE;
            if (self.current == 0) self.zeros += 1;
        }
    }

    pub fn getPassword(self: *Module) !usize {
        return self.zeros;
    }
};

test "sample part 1" {
    const data =
        \\L68
        \\L30
        \\R48
        \\L5
        \\R60
        \\L55
        \\L1
        \\L99
        \\R14
        \\L82
    ;

    var module = Module.init(false);
    try module.parseInput(data);

    const password = try module.getPassword();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, password);
}

test "sample part 2" {
    const data =
        \\L68
        \\L30
        \\R48
        \\L5
        \\R60
        \\L55
        \\L1
        \\L99
        \\R14
        \\L82
    ;

    var module = Module.init(true);
    try module.parseInput(data);

    const password = try module.getPassword();
    const expected = @as(usize, 6);
    try testing.expectEqual(expected, password);
}
