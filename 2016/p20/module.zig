const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Firewall = struct {
    const Rule = struct {
        beg: usize,
        end: usize,

        pub fn parse(str: []const u8) !Rule {
            var it = std.mem.tokenizeScalar(u8, str, '-');
            var rule: Rule = undefined;
            rule.beg = try std.fmt.parseUnsigned(usize, it.next().?, 10);
            rule.end = try std.fmt.parseUnsigned(usize, it.next().?, 10);
            return rule;
        }

        pub fn lessThan(_: void, l: Rule, r: Rule) bool {
            if (l.beg < r.beg) return true;
            if (l.beg > r.beg) return false;
            return l.end < r.end;
        }
    };

    rules: std.ArrayList(Rule),
    top: usize,
    lowest: usize,
    count: usize,

    pub fn init(allocator: Allocator, top: usize) Firewall {
        const t: usize = if (top == 0) std.math.maxInt(u32) else top;
        return .{
            .top = t,
            .rules = std.ArrayList(Rule).init(allocator),
            .lowest = 0,
            .count = 0,
        };
    }

    pub fn deinit(self: *Firewall) void {
        self.rules.deinit();
    }

    pub fn addLine(self: *Firewall, line: []const u8) !void {
        const rule = try Rule.parse(line);
        try self.rules.append(rule);
    }

    pub fn show(self: Firewall) void {
        std.debug.print("Firewall with {} rules\n", .{self.rules.items.len});
        for (self.rules.items, 0..) |r, p| {
            std.debug.print("  Rule #{}: {} - {}\n", .{ p + 1, r.beg, r.end });
        }
    }

    pub fn getLowestAdressAllowed(self: *Firewall) !usize {
        self.processRules();
        return self.lowest;
    }

    pub fn getAllowedAdressCount(self: *Firewall) !usize {
        self.processRules();
        return self.count;
    }

    fn processRules(self: *Firewall) void {
        std.mem.sort(Rule, self.rules.items, {}, Rule.lessThan);
        self.lowest = std.math.maxInt(usize);
        self.count = 0;

        var first = true;
        var beg: usize = 0;
        var end: usize = std.math.maxInt(usize);
        for (self.rules.items) |r| {
            if (first) {
                if (r.beg > 0) {
                    self.lowest = 0;
                    self.count += r.beg - 1;
                }
                beg = r.beg;
                end = r.end;
                first = false;
                continue;
            }
            if (r.beg <= end) {
                if (r.end > end) {
                    end = r.end;
                }
                continue;
            }
            if (r.beg == end + 1) {
                end = r.end;
                continue;
            }
            if (self.lowest > r.beg - 1) {
                self.lowest = r.beg - 1;
            }
            self.count += r.beg - 1 - end;
            beg = r.beg;
            end = r.end;
        }
        if (self.top > end) {
            if (self.lowest > end + 1) {
                self.lowest = end + 1;
            }
            self.count += self.top - end;
        }
    }
};

test "sample part 1" {
    const data =
        \\5-8
        \\0-2
        \\4-7
    ;

    var firewall = Firewall.init(std.testing.allocator, 9);
    defer firewall.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try firewall.addLine(line);
    }
    // firewall.show();

    const lowest = try firewall.getLowestAdressAllowed();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, lowest);
}

test "sample part 2" {
    const data =
        \\5-8
        \\0-2
        \\4-7
    ;

    var firewall = Firewall.init(std.testing.allocator, 9);
    defer firewall.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try firewall.addLine(line);
    }
    // firewall.show();

    const count = try firewall.getAllowedAdressCount();
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, count);
}
