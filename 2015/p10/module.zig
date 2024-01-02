const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Sequence = struct {
    allocator: Allocator,
    seqs: [2]std.ArrayList(usize), // we flip-flop between the two
    pos: usize,

    pub fn init(allocator: Allocator) Sequence {
        var self = Sequence{
            .allocator = allocator,
            .seqs = undefined,
            .pos = 0,
        };
        for (self.seqs, 0..) |_, pos| {
            self.seqs[pos] = std.ArrayList(usize).init(allocator);
        }
        return self;
    }

    pub fn deinit(self: *Sequence) void {
        for (self.seqs) |seq| {
            seq.deinit();
        }
    }

    pub fn addLine(self: *Sequence, line: []const u8) !void {
        self.seqs[self.pos].clearRetainingCapacity();
        for (line) |c| {
            try self.seqs[self.pos].append(c - '0');
        }
    }

    pub fn lookAndSay(self: *Sequence, times: usize) !usize {
        for (0..times) |_| {
            try self.lookAndSayOnce();
        }
        return self.seqs[self.pos].items.len;
    }

    fn lookAndSayOnce(self: *Sequence) !void {
        const nxt = 1 - self.pos;
        self.seqs[nxt].clearRetainingCapacity();

        var digit: usize = std.math.maxInt(usize);
        var count: usize = 0;
        for (self.seqs[self.pos].items) |current| {
            if (digit == current) {
                count += 1;
            } else {
                try self.checkAndSave(nxt, digit, count);
                digit = current;
                count = 1;
            }
        }
        try self.checkAndSave(nxt, digit, count);
        self.pos = nxt;
    }

    fn checkAndSave(self: *Sequence, nxt: usize, digit: usize, count: usize) !void {
        if (count == 0) return;
        if (count >= 10) {
            // we would need to output each of count's digits here
            // the input doesn't need to require it -- screw it
            unreachable;
        }
        try self.seqs[nxt].append(count);
        try self.seqs[nxt].append(digit);
    }

    fn matches(self: Sequence, text: []const u8) bool { // just to test
        var pos: usize = 0;
        for (self.seqs[self.pos].items) |digit| {
            if (pos >= text.len) return false;
            if (digit != text[pos] - '0') return false;
            pos += 1;
        }
        return true;
    }
};

test "sample part 1 piecewise" {
    {
        var sequence = Sequence.init(std.testing.allocator);
        defer sequence.deinit();
        try sequence.addLine("1");
        try sequence.lookAndSayOnce();
        try testing.expect(sequence.matches("11"));
    }
    {
        var sequence = Sequence.init(std.testing.allocator);
        defer sequence.deinit();
        try sequence.addLine("11");
        try sequence.lookAndSayOnce();
        try testing.expect(sequence.matches("21"));
    }
    {
        var sequence = Sequence.init(std.testing.allocator);
        defer sequence.deinit();
        try sequence.addLine("21");
        try sequence.lookAndSayOnce();
        try testing.expect(sequence.matches("1211"));
    }
    {
        var sequence = Sequence.init(std.testing.allocator);
        defer sequence.deinit();
        try sequence.addLine("1211");
        try sequence.lookAndSayOnce();
        try testing.expect(sequence.matches("111221"));
    }
    {
        var sequence = Sequence.init(std.testing.allocator);
        defer sequence.deinit();
        try sequence.addLine("111221");
        try sequence.lookAndSayOnce();
        try testing.expect(sequence.matches("312211"));
    }
}

test "sample part 1 iterations" {
    {
        var sequence = Sequence.init(std.testing.allocator);
        defer sequence.deinit();
        try sequence.addLine("1");
        const length = try sequence.lookAndSay(5);
        try testing.expect(sequence.matches("312211"));
        const expected = @as(usize, 6);
        try testing.expectEqual(expected, length);
    }
}
