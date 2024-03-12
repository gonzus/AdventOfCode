const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Adder = struct {
    allocator: Allocator,
    frecuencies: std.ArrayList(isize),

    pub fn init(allocator: Allocator) Adder {
        return .{
            .allocator = allocator,
            .frecuencies = std.ArrayList(isize).init(allocator),
        };
    }

    pub fn deinit(self: *Adder) void {
        self.frecuencies.deinit();
    }

    pub fn addLine(self: *Adder, line: []const u8) !void {
        var it = std.mem.tokenizeAny(u8, line, " ,");
        while (it.next()) |chunk| {
            const num = try std.fmt.parseInt(isize, chunk, 10);
            try self.frecuencies.append(num);
        }
    }

    pub fn getFinalFrequency(self: Adder) isize {
        var frequency: isize = 0;
        for (self.frecuencies.items) |f| {
            frequency += f;
        }
        return frequency;
    }

    pub fn getFirstRepeatedFrequency(self: Adder) !isize {
        var seen = std.AutoHashMap(isize, void).init(self.allocator);
        defer seen.deinit();
        var frequency: isize = 0;
        _ = try seen.getOrPut(frequency);
        SEARCH: while (true) {
            for (self.frecuencies.items) |f| {
                frequency += f;
                const r = try seen.getOrPut(frequency);
                if (r.found_existing) break :SEARCH;
            }
        }
        return frequency;
    }
};

test "sample part 1 case A" {
    const data =
        \\+1, -2, +3, +1
    ;

    var adder = Adder.init(testing.allocator);
    defer adder.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try adder.addLine(line);
    }

    const frequency = adder.getFinalFrequency();
    const expected = @as(isize, 3);
    try testing.expectEqual(expected, frequency);
}

test "sample part 1 case B" {
    const data =
        \\+1, +1, +1
    ;

    var adder = Adder.init(testing.allocator);
    defer adder.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try adder.addLine(line);
    }

    const frequency = adder.getFinalFrequency();
    const expected = @as(isize, 3);
    try testing.expectEqual(expected, frequency);
}

test "sample part 1 case C" {
    const data =
        \\+1, +1, -2
    ;

    var adder = Adder.init(testing.allocator);
    defer adder.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try adder.addLine(line);
    }

    const frequency = adder.getFinalFrequency();
    const expected = @as(isize, 0);
    try testing.expectEqual(expected, frequency);
}

test "sample part 1 case D" {
    const data =
        \\-1, -2, -3
    ;

    var adder = Adder.init(testing.allocator);
    defer adder.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try adder.addLine(line);
    }

    const frequency = adder.getFinalFrequency();
    const expected = @as(isize, -6);
    try testing.expectEqual(expected, frequency);
}

test "sample part 2 case A" {
    const data =
        \\+1, -2, +3, +1
    ;

    var adder = Adder.init(testing.allocator);
    defer adder.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try adder.addLine(line);
    }

    const frequency = try adder.getFirstRepeatedFrequency();
    const expected = @as(isize, 2);
    try testing.expectEqual(expected, frequency);
}

test "sample part 2 case B" {
    const data =
        \\+1, -1
    ;

    var adder = Adder.init(testing.allocator);
    defer adder.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try adder.addLine(line);
    }

    const frequency = try adder.getFirstRepeatedFrequency();
    const expected = @as(isize, 0);
    try testing.expectEqual(expected, frequency);
}

test "sample part 2 case C" {
    const data =
        \\+3, +3, +4, -2, -4
    ;

    var adder = Adder.init(testing.allocator);
    defer adder.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try adder.addLine(line);
    }

    const frequency = try adder.getFirstRepeatedFrequency();
    const expected = @as(isize, 10);
    try testing.expectEqual(expected, frequency);
}

test "sample part 2 case D" {
    const data =
        \\-6, +3, +8, +5, -6
    ;

    var adder = Adder.init(testing.allocator);
    defer adder.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try adder.addLine(line);
    }

    const frequency = try adder.getFirstRepeatedFrequency();
    const expected = @as(isize, 5);
    try testing.expectEqual(expected, frequency);
}

test "sample part 2 case E" {
    const data =
        \\+7, +7, -2, -7, -4
    ;

    var adder = Adder.init(testing.allocator);
    defer adder.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try adder.addLine(line);
    }

    const frequency = try adder.getFirstRepeatedFrequency();
    const expected = @as(isize, 14);
    try testing.expectEqual(expected, frequency);
}
