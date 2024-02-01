const std = @import("std");
const testing = std.testing;

pub const Party = struct {
    elves: usize,

    pub fn init() Party {
        return .{ .elves = 0 };
    }

    pub fn addLine(self: *Party, line: []const u8) !void {
        self.elves = try std.fmt.parseUnsigned(usize, line, 10);
    }

    pub fn getWinningElfNext(self: Party) usize {
        const num = self.elves - highestOneBit(@intCast(self.elves));
        return 2 * num + 1;
    }

    pub fn getWinningElfAcross(self: Party) usize {
        var elf: usize = 1;
        for (1..self.elves) |round| {
            elf %= round;
            elf += 1;
            if (elf > (round + 1) / 2) {
                elf += 1;
            }
        }
        return elf;
    }

    fn highestOneBit(u: u32) u32 {
        var v = u;
        v |= (v >> 1);
        v |= (v >> 2);
        v |= (v >> 4);
        v |= (v >> 8);
        v |= (v >> 16);
        return v - (v >> 1);
    }
};

test "sample part 1" {
    const data =
        \\5
    ;

    var party = Party.init();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try party.addLine(line);
    }

    const winner = party.getWinningElfNext();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, winner);
}

test "sample part 2" {
    const data =
        \\5
    ;

    var party = Party.init();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try party.addLine(line);
    }

    const winner = party.getWinningElfAcross();
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, winner);
}
