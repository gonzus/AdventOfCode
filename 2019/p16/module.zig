const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const FFT = struct {
    const Data = std.ArrayList(u8);
    const OFFSET_LENGTH = 7;
    const SIGNAL_LENGTH = 8;
    const BASE_PATTERN = [_]i8{ 0, 1, 0, -1 };

    allocator: Allocator,
    signal: Data,
    output: Data,
    offset: usize,

    pub fn init(allocator: Allocator) FFT {
        return .{
            .allocator = allocator,
            .signal = Data.init(allocator),
            .output = Data.init(allocator),
            .offset = 0,
        };
    }

    pub fn deinit(self: *FFT) void {
        self.output.deinit();
        self.signal.deinit();
    }

    pub fn addLine(self: *FFT, line: []const u8) !void {
        for (0..line.len) |p| {
            const d: u8 = line[p] - '0';
            try self.signal.append(d);
            if (p < OFFSET_LENGTH) {
                self.offset *= 10;
                self.offset += d;
            }
        }
    }

    pub fn getSignal(self: *FFT, phases: usize, repeat: usize, use_offset: bool) ![]const u8 {
        self.output.clearRetainingCapacity();
        const total = repeat * self.signal.items.len;
        var offset: usize = 0;
        if (use_offset) offset = self.offset;
        try self.runManyPhases(phases, repeat, total - offset);
        for (0..SIGNAL_LENGTH) |p| {
            self.output.items[offset + p] += '0';
        }
        return self.output.items[offset .. offset + SIGNAL_LENGTH];
    }

    fn getPattern(r: usize, p: usize) i8 {
        const pos = ((p + 1) / (r + 1)) % 4;
        return BASE_PATTERN[pos];
    }

    fn runManyPhases(self: *FFT, phases: usize, repeat: usize, last: usize) !void {
        var buf: [2]Data = undefined;
        for (0..2) |p| {
            buf[p] = Data.init(self.allocator);
        }
        defer {
            for (0..2) |p| {
                buf[p].deinit();
            }
        }

        var inp: usize = 0;
        var out: usize = 1;
        for (0..repeat) |_| {
            try buf[inp].appendSlice(self.signal.items);
        }
        try buf[out].resize(buf[inp].items.len);
        for (0..phases) |_| {
            self.runOnePhase(buf, inp, out, repeat, last);
            inp = 1 - inp;
            out = 1 - out;
        }
        try self.output.appendSlice(buf[inp].items);
    }

    fn runOnePhase(self: *FFT, buf: [2]Data, inp: usize, out: usize, repeat: usize, last: usize) void {
        const total = repeat * self.signal.items.len;
        const first = total - last;
        const half = total / 2;
        var j: usize = total;
        var g: u32 = 0;
        while (j > first and j > half) {
            j -= 1;
            g += buf[inp].items[j];
            buf[out].items[j] = @intCast(g % 10);
        }
        while (j > first) {
            j -= 1;
            var d: i32 = 0;
            var k: usize = total;
            while (true) {
                k -= 1;
                const s: i32 = @intCast(buf[inp].items[k]);
                d += s * getPattern(j, k);
                if (k == j) break;
                if ((total - k) == last) break;
            }
            buf[out].items[j] = @intCast(@abs(d) % 10);
        }
    }
};

test "sample part 1 case A" {
    var fft = FFT.init(testing.allocator);
    defer fft.deinit();

    const data =
        \\80871224585914546619083218645595
    ;
    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try fft.addLine(line);
    }

    const expected = "24176176";
    const output = try fft.getSignal(100, 1, false);
    try testing.expectEqualStrings(expected, output);
}

test "sample part 1 case B" {
    var fft = FFT.init(testing.allocator);
    defer fft.deinit();

    const data =
        \\19617804207202209144916044189917
    ;
    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try fft.addLine(line);
    }

    const expected = "73745418";
    const output = try fft.getSignal(100, 1, false);
    try testing.expectEqualStrings(expected, output);
}

test "sample part 1 case C" {
    var fft = FFT.init(testing.allocator);
    defer fft.deinit();

    const data =
        \\69317163492948606335995924319873
    ;
    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try fft.addLine(line);
    }

    const expected = "52432133";
    const output = try fft.getSignal(100, 1, false);
    try testing.expectEqualStrings(expected, output);
}

test "sample part 2 case A" {
    var fft = FFT.init(testing.allocator);
    defer fft.deinit();

    const data =
        \\03036732577212944063491565474664
    ;
    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try fft.addLine(line);
    }

    const expected = "84462026";
    const output = try fft.getSignal(100, 10_000, true);
    try testing.expectEqualStrings(expected, output);
}

test "sample part 2 case B" {
    var fft = FFT.init(testing.allocator);
    defer fft.deinit();

    const data =
        \\02935109699940807407585447034323
    ;
    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try fft.addLine(line);
    }

    const expected = "78725270";
    const output = try fft.getSignal(100, 10_000, true);
    try testing.expectEqualStrings(expected, output);
}

test "sample part 2 case C" {
    var fft = FFT.init(testing.allocator);
    defer fft.deinit();

    const data =
        \\03081770884921959731165446850517
    ;
    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try fft.addLine(line);
    }

    const expected = "53553731";
    const output = try fft.getSignal(100, 10_000, true);
    try testing.expectEqualStrings(expected, output);
}
