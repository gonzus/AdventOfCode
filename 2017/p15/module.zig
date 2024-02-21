const std = @import("std");
const testing = std.testing;

pub const Duel = struct {
    const SIZE = 2;

    const GeneratorProps = struct {
        factor: usize,
        filter: usize,
    };
    const Props = [SIZE]GeneratorProps{
        GeneratorProps{ .factor = 16807, .filter = 4 }, // generator A
        GeneratorProps{ .factor = 48271, .filter = 8 }, // generator B
    };

    const Generator = struct {
        const DIVISOR = 2147483647;

        factor: usize,
        filter: usize,
        current: usize,

        pub fn init(gen: usize, picky: bool, start: usize) Generator {
            const props = Props[gen];
            return .{
                .factor = props.factor,
                .filter = if (picky) props.filter else 0,
                .current = start,
            };
        }

        pub fn next(self: *Generator) void {
            while (true) {
                self.current = (self.current * self.factor) % DIVISOR;
                if (self.filter == 0) break;
                if (self.current % self.filter == 0) break;
            }
        }

        pub fn match(self: Generator, other: Generator) bool {
            return self.current & 0xffff == other.current & 0xffff;
        }
    };

    picky: bool,
    gen: [SIZE]Generator,

    pub fn init(picky: bool) Duel {
        return .{
            .picky = picky,
            .gen = undefined,
        };
    }

    pub fn addLine(self: *Duel, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        _ = it.next();
        const label = it.next().?;
        const gen = label[0] - 'A';
        _ = it.next();
        _ = it.next();
        const num = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        self.gen[gen] = Generator.init(gen, self.picky, num);
    }

    pub fn countMatchesUpTo(self: *Duel, rounds: usize) !usize {
        var count: usize = 0;
        for (0..rounds) |_| {
            if (self.next()) count += 1;
        }
        return count;
    }

    fn next(self: *Duel) bool {
        var matches: usize = 1; // pos 0 matches with itself
        for (0..SIZE) |p| {
            self.gen[p].next();
            if (p == 0) continue;
            if (self.gen[0].match(self.gen[p])) matches += 1;
        }
        return matches == SIZE;
    }
};

test "sample part 1 case A" {
    const data =
        \\Generator A starts with 65
        \\Generator B starts with 8921
    ;

    var duel = Duel.init(false);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try duel.addLine(line);
    }

    const count = try duel.countMatchesUpTo(5);
    const expected = @as(usize, 1);
    try testing.expectEqual(expected, count);
}

test "sample part 1 case B" {
    const data =
        \\Generator A starts with 65
        \\Generator B starts with 8921
    ;

    var duel = Duel.init(false);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try duel.addLine(line);
    }

    const count = try duel.countMatchesUpTo(40_000_000);
    const expected = @as(usize, 588);
    try testing.expectEqual(expected, count);
}

test "sample part 2 case A" {
    const data =
        \\Generator A starts with 65
        \\Generator B starts with 8921
    ;

    var duel = Duel.init(true);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try duel.addLine(line);
    }

    const count = try duel.countMatchesUpTo(5);
    const expected = @as(usize, 0);
    try testing.expectEqual(expected, count);
}

test "sample part 2 case B" {
    const data =
        \\Generator A starts with 65
        \\Generator B starts with 8921
    ;

    var duel = Duel.init(true);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try duel.addLine(line);
    }

    const count = try duel.countMatchesUpTo(5_000_000);
    const expected = @as(usize, 309);
    try testing.expectEqual(expected, count);
}
