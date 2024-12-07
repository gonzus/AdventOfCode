const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Printer = struct {
    const State = enum { rules, pages };
    const PageList = std.ArrayList(usize);

    const Rule = struct {
        bef: usize,
        aft: usize,

        pub fn init(bef: usize, aft: usize) Rule {
            return .{ .bef = bef, .aft = aft };
        }
    };

    allocator: Allocator,
    fix: bool,
    state: State,
    rules: std.ArrayList(Rule),
    pagelist: std.ArrayList(PageList),

    pub fn init(allocator: Allocator, fix: bool) Printer {
        const self = Printer{
            .allocator = allocator,
            .fix = fix,
            .state = .rules,
            .rules = std.ArrayList(Rule).init(allocator),
            .pagelist = std.ArrayList(PageList).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Printer) void {
        for (self.pagelist.items) |*p| {
            p.*.deinit();
        }
        self.pagelist.deinit();
        self.rules.deinit();
    }

    pub fn addLine(self: *Printer, line: []const u8) !void {
        if (line.len == 0) {
            self.state = .pages;
            return;
        }
        switch (self.state) {
            .rules => {
                var it = std.mem.tokenizeScalar(u8, line, '|');
                var pages: [2]usize = undefined;
                var pos: usize = 0;
                while (it.next()) |chunk| : (pos += 1) {
                    pages[pos] = try std.fmt.parseUnsigned(usize, chunk, 10);
                }
                if (pos != 2) return error.InvalidRule;
                try self.rules.append(Rule.init(pages[0], pages[1]));
            },
            .pages => {
                var pages = PageList.init(self.allocator);
                var it = std.mem.tokenizeScalar(u8, line, ',');
                while (it.next()) |chunk| {
                    const page = try std.fmt.parseUnsigned(usize, chunk, 10);
                    try pages.append(page);
                }
                try self.pagelist.append(pages);
            },
        }
    }

    fn cmpRules(rules: []Rule, l: usize, r: usize) bool {
        for (rules) |rule| {
            if (l == rule.bef and r == rule.aft) return true;
            if (l == rule.aft and r == rule.bef) return false;
        }
        return false;
    }

    pub fn sumMiddlePages(self: *Printer) !usize {
        var sum: usize = 0;
        for (self.pagelist.items) |pages| {
            var sorted = try pages.clone();
            defer sorted.deinit();
            std.mem.sort(usize, sorted.items, self.rules.items, cmpRules);
            const eql = std.mem.eql(usize, sorted.items, pages.items);
            if ((!self.fix and eql) or (self.fix and !eql)) {
                const middle = sorted.items.len / 2;
                sum += sorted.items[middle];
            }
        }
        return sum;
    }
};

test "sample part 1" {
    const data =
        \\47|53
        \\97|13
        \\97|61
        \\97|47
        \\75|29
        \\61|13
        \\75|53
        \\29|13
        \\97|29
        \\53|29
        \\61|53
        \\97|53
        \\61|29
        \\47|13
        \\75|47
        \\97|75
        \\47|61
        \\75|61
        \\47|29
        \\75|13
        \\53|13
        \\
        \\75,47,61,53,29
        \\97,61,53,29,13
        \\75,29,13
        \\75,97,47,61,53
        \\61,13,29
        \\97,13,75,29,47
    ;

    var printer = Printer.init(testing.allocator, false);
    defer printer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try printer.addLine(line);
    }

    const count = try printer.sumMiddlePages();
    const expected = @as(usize, 143);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\47|53
        \\97|13
        \\97|61
        \\97|47
        \\75|29
        \\61|13
        \\75|53
        \\29|13
        \\97|29
        \\53|29
        \\61|53
        \\97|53
        \\61|29
        \\47|13
        \\75|47
        \\97|75
        \\47|61
        \\75|61
        \\47|29
        \\75|13
        \\53|13
        \\
        \\75,47,61,53,29
        \\97,61,53,29,13
        \\75,29,13
        \\75,97,47,61,53
        \\61,13,29
        \\97,13,75,29,47
    ;

    var printer = Printer.init(testing.allocator, true);
    defer printer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try printer.addLine(line);
    }

    const count = try printer.sumMiddlePages();
    const expected = @as(usize, 123);
    try testing.expectEqual(expected, count);
}
