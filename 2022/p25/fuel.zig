const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Bob = struct {
    fuels: std.ArrayList(usize),

    pub fn init(allocator: Allocator) Bob {
        const self = Bob{
            .fuels = std.ArrayList(usize).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Bob) void {
        self.fuels.deinit();
    }

    pub fn convert_5_to_10(src: []const u8) usize {
        var num: usize = 0;
        for (src) |c| {
            const d: isize = switch (c) {
                '2' => 2,
                '1' => 1,
                '0' => 0,
                '-' => -1,
                '=' => -2,
                else => unreachable,
            };
            num *= 5;
            num = @as(usize, @intCast(@as(isize, @intCast(num)) + d));
        }
        return num;
    }

    pub fn convert_10_to_5(num: usize, buf: []u8) []const u8 {
        var p: usize = 0;
        var q: usize = 0;
        var tmp: [100]u8 = undefined;

        // initialize buf to all zeroes
        p = 0;
        while (p < buf.len) : (p += 1) {
            buf[p] = 0;
        }

        // initialize tmp to all zeroes
        p = 0;
        while (p < tmp.len) : (p += 1) {
            tmp[p] = 0;
        }

        // convert to regular base 5 into buf
        var copy = num;
        // std.debug.print("Converting {}\n", .{copy});
        p = 0;
        while (true) {
            const d = copy % 5;
            copy /= 5;
            buf[p] = '0' + @as(u8, @intCast(d));
            // std.debug.print(" DIGIT5 {} = {c}\n", .{p, buf[p]});
            p += 1;
            if (copy == 0) break;
        }

        // "correct" the conversion to balanced base 5 into tmp
        q = 0;
        while (buf[q] > 0) : (q += 1) {
            tmp[q] = switch (buf[q]) {
                '0' => '0',
                '1' => '1',
                '2' => '2',
                '3' => '=',
                '4' => '-',
                '5' => '0',
                else => unreachable,
            };
            if (buf[q] <= '2') continue;
            if (buf[q + 1] == 0) buf[q + 1] = '0';
            buf[q + 1] += 1;
        }

        // create a slice with the reversed digits
        q = 0;
        while (tmp[q] != 0) : (q += 1) {
            // std.debug.print("D{} = {c}\n", .{q, tmp[q]});
            buf[buf.len - 1 - q] = tmp[q];
        }
        p = buf.len - q;

        return buf[p .. p + q];
    }

    pub fn add_line(self: *Bob, line: []const u8) !void {
        const num = convert_5_to_10(line);
        try self.fuels.append(num);
    }

    pub fn show(self: Bob) void {
        std.debug.print("-- Fuels --------\n", .{});
        for (self.fuels.items) |fuel| {
            std.debug.print("{}\n", .{fuel});
        }
    }

    pub fn total_fuel(self: Bob) usize {
        var total: usize = 0;
        for (self.fuels.items) |fuel| {
            total += fuel;
        }
        return total;
    }
};

test "sample part simple" {
    var cases = std.StringHashMap(usize).init(std.testing.allocator);
    defer cases.deinit();

    try cases.put("1", 1);
    try cases.put("2", 2);
    try cases.put("1=", 3);
    try cases.put("1-", 4);
    try cases.put("10", 5);
    try cases.put("11", 6);
    try cases.put("12", 7);
    try cases.put("2=", 8);
    try cases.put("2-", 9);
    try cases.put("20", 10);
    try cases.put("1=0", 15);
    try cases.put("1-0", 20);
    try cases.put("1=11-2", 2022);
    try cases.put("1-0---0", 12345);
    try cases.put("1121-1110-1=0", 314159265);

    var it = cases.iterator();
    while (it.next()) |e| {
        const snafu = e.key_ptr.*;
        const number = e.value_ptr.*;

        const snafu_to_number = Bob.convert_5_to_10(snafu);
        try testing.expectEqual(number, snafu_to_number);

        var buf: [100]u8 = undefined;
        const number_to_snafu = Bob.convert_10_to_5(number, &buf);
        try testing.expectEqualStrings(snafu, number_to_snafu);
    }
}

test "sample part 1" {
    const data: []const u8 =
        \\1=-0-2
        \\12111
        \\2=0=
        \\21
        \\2=01
        \\111
        \\20012
        \\112
        \\1=-1=
        \\1-12
        \\12
        \\1=
        \\122
    ;

    var bob = Bob.init(std.testing.allocator);
    defer bob.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try bob.add_line(line);
    }
    // bob.show();

    const fuel = bob.total_fuel();
    try testing.expectEqual(@as(usize, 4890), fuel);

    var buf: [100]u8 = undefined;
    const snafu = Bob.convert_10_to_5(fuel, &buf);
    try testing.expectEqualStrings("2=-1=0", snafu);
}
