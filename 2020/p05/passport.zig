const std = @import("std");
const testing = std.testing;

pub const Passport = struct {
    seen: std.AutoHashMap(usize, void),

    pub fn init() Passport {
        const allocator = std.heap.page_allocator;
        var self = Passport{
            .seen = std.AutoHashMap(usize, void).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Passport) void {
        self.seen.deinit();
    }

    pub fn parse(self: *Passport, line: []const u8) usize {
        const row = self.parse_binary(line[0..7]);
        const col = self.parse_binary(line[7..10]);
        const id = row * 8 + col;
        // std.debug.warn("LINE [{}] = {} * {} = {}\n", .{ line, row, col, id });
        self.add(id);
        return id;
    }

    pub fn find_missing(self: *Passport) usize {
        var candidate: usize = 1;
        while (candidate < 10000) : (candidate += 1) {
            if (self.seen.contains(candidate)) {
                continue;
            }
            if (!self.seen.contains(candidate + 1)) {
                continue;
            }
            if (!self.seen.contains(candidate - 1)) {
                continue;
            }
            return candidate;
        }
        return 0;
    }

    fn parse_binary(self: *Passport, str: []const u8) usize {
        var value: usize = 0;
        for (str) |c| {
            value *= 2;
            if (c == 'B' or c == 'R') {
                value += 1;
            }
        }
        return value;
    }

    fn add(self: *Passport, value: usize) void {
        if (self.seen.contains(value)) {
            return;
        }
        _ = self.seen.put(value, {}) catch unreachable;
    }
};

test "sample no validation" {
    const data: []const u8 =
        \\FBFBBFFRLR 357
        \\BFFFBBFRRR 567
        \\FFFBBBFRRR 119
        \\BBFFBBFRLL 820
    ;

    var passport = Passport.init();
    defer passport.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        var itf = std.mem.tokenize(line, " ");
        const pstr = itf.next().?;
        const istr = itf.next().?;
        const expected = std.fmt.parseInt(usize, istr, 10) catch unreachable;
        const id = passport.parse(pstr);
        testing.expect(id == expected);
    }
}
