const std = @import("std");
const testing = std.testing;

pub const Computer = struct {
    conditional: bool,
    do: bool,
    total: usize,

    pub fn init(conditional: bool) Computer {
        const self = Computer{
            .conditional = conditional,
            .do = true,
            .total = 0,
        };
        return self;
    }

    pub fn deinit(_: *Computer) void {}

    pub fn addLine(self: *Computer, line: []const u8) !void {
        var window = std.mem.window(u8, line, 7, 1);
        while (window.next()) |prefix| {
            if (std.mem.eql(u8, prefix[0..4], "mul(")) {
                if (self.do) {
                    const args = std.mem.sliceTo(line[window.index.? + 3 ..], ')');
                    var pos: usize = 0;
                    var nums: [2]usize = [_]usize{ 0, 0 };
                    var it = std.mem.tokenizeScalar(u8, args, ',');
                    while (it.next()) |chunk| {
                        if (pos >= 2) break;
                        const num = std.fmt.parseUnsigned(usize, chunk, 10) catch {
                            pos = 99;
                            break;
                        };
                        nums[pos] = num;
                        pos += 1;
                    }
                    if (pos > 2) continue;
                    const product = nums[0] * nums[1];
                    self.total += product;
                }
                continue;
            }
            if (!self.conditional) continue;
            if (std.mem.eql(u8, prefix[0..7], "don't()")) {
                self.do = false;
                continue;
            }
            if (std.mem.eql(u8, prefix[0..4], "do()")) {
                self.do = true;
                continue;
            }
        }
    }

    pub fn runMultiplies(self: Computer) !usize {
        return self.total;
    }
};

test "sample part 1" {
    const data =
        \\xmul(2,4)%&mul[3,7]!@^do_not_mul(5,5)+mul(32,64]then(mul(11,8)mul(8,5))
    ;

    var computer = Computer.init(false);
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.addLine(line);
    }

    const count = computer.runMultiplies();
    const expected = @as(usize, 161);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\xmul(2,4)&mul[3,7]!^don't()_mul(5,5)+mul(32,64](mul(11,8)undo()?mul(8,5))
    ;

    var computer = Computer.init(true);
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.addLine(line);
    }

    const count = computer.runMultiplies();
    const expected = @as(usize, 48);
    try testing.expectEqual(expected, count);
}
