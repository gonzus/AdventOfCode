const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Engine = struct {
    const StringId = StringTable.StringId;

    const STARTING_WORKFLOW = "in";
    const ACTION_ACCEPT = "A";
    const ACTION_REJECT = "R";

    const Category = enum {
        x,
        m,
        a,
        s,

        pub fn parse(c: u8) Category {
            return switch (c) {
                'x' => .x,
                'm' => .m,
                'a' => .a,
                's' => .s,
                else => unreachable,
            };
        }
    };
    const CATEGORY_SIZE = std.meta.tags(Category).len;

    const Cmp = enum {
        LT,
        GT,

        pub fn parse(c: u8) Cmp {
            return switch (c) {
                '<' => .LT,
                '>' => .GT,
                else => unreachable,
            };
        }
    };

    const Range = struct {
        category: Category,
        cmp: Cmp,
        value: usize,

        pub fn init(category: Category, cmp: Cmp, value: usize) Range {
            const self = Range{ .category = category, .cmp = cmp, .value = value };
            return self;
        }
    };
    const RangeGroup = std.ArrayList(Range);
    const RangeGroupList = std.ArrayList(RangeGroup);

    const Rule = struct {
        range: Range,
        target: StringId,

        pub fn init(category: Category, cmp: Cmp, value: usize, target: StringId) Rule {
            const range = Range.init(category, cmp, value);
            const self = Rule{ .range = range, .target = target };
            return self;
        }

        pub fn match(self: Rule, part: Part) bool {
            const value = part.getRating(self.range.category);
            const ok = switch (self.range.cmp) {
                .LT => value < self.range.value,
                .GT => value > self.range.value,
            };
            return ok;
        }
    };

    const Workflow = struct {
        rules: std.ArrayList(Rule),
        default: StringId,

        pub fn init(allocator: Allocator) Workflow {
            const self = Workflow{
                .default = undefined,
                .rules = std.ArrayList(Rule).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: Workflow) void {
            self.rules.deinit();
        }

        pub fn setDefault(self: *Workflow, default: StringId) !void {
            self.default = default;
        }

        pub fn run(self: Workflow, part: Part) StringId {
            for (self.rules.items) |rule| {
                if (rule.match(part)) {
                    return rule.target;
                }
            }
            return self.default;
        }
    };

    const Part = struct {
        ratings: [CATEGORY_SIZE]usize,

        pub fn init() Part {
            return Part{ .ratings = [_]usize{0} ** CATEGORY_SIZE };
        }

        pub fn getRating(self: Part, c: Category) usize {
            return self.ratings[@intFromEnum(c)];
        }

        pub fn setRating(self: *Part, c: Category, value: usize) void {
            self.ratings[@intFromEnum(c)] = value;
        }

        pub fn getTotalRating(self: Part) usize {
            var total: usize = 0;
            for (std.meta.tags(Category)) |c| {
                total += self.getRating(c);
            }
            return total;
        }
    };

    allocator: Allocator,
    in_parts: bool,
    strtab: StringTable,
    workflows: std.AutoHashMap(StringId, Workflow),
    parts: std.ArrayList(Part),
    ranges: RangeGroupList,

    pub fn init(allocator: Allocator) Engine {
        const self = Engine{
            .allocator = allocator,
            .in_parts = false,
            .strtab = StringTable.init(allocator),
            .workflows = std.AutoHashMap(StringId, Workflow).init(allocator),
            .parts = std.ArrayList(Part).init(allocator),
            .ranges = RangeGroupList.init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Engine) void {
        for (self.ranges.items) |range| {
            range.deinit();
        }
        self.ranges.deinit();
        self.parts.deinit();
        var it = self.workflows.valueIterator();
        while (it.next()) |workflow| {
            workflow.deinit();
        }
        self.workflows.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Engine, line: []const u8) !void {
        if (line.len == 0) {
            self.in_parts = true;
            return;
        }

        if (self.in_parts) {
            var part = Part.init();
            const parts = line[1 .. line.len - 1];
            var it_part = std.mem.tokenizeScalar(u8, parts, ',');
            while (it_part.next()) |chunk_value| {
                var it_value = std.mem.tokenizeScalar(u8, chunk_value, '=');
                const name = it_value.next().?;
                const value = try std.fmt.parseUnsigned(usize, it_value.next().?, 10);
                const category = Category.parse(name[0]);
                part.setRating(category, value);
            }
            try self.parts.append(part);
            return;
        }

        var it_workflow = std.mem.tokenizeAny(u8, line, "{}");
        const name = it_workflow.next().?;
        var workflow = Workflow.init(self.allocator);

        const rules = it_workflow.next().?;
        var it_rules = std.mem.tokenizeScalar(u8, rules, ',');
        while (it_rules.next()) |parts| {
            var beg: usize = 0;
            var pos: usize = 0;
            while (pos < parts.len and std.ascii.isAlphabetic(parts[pos])) : (pos += 1) {}
            const what = parts[beg..pos];
            if (pos >= parts.len) {
                const sp = try self.strtab.add(what);
                try workflow.setDefault(sp);
                continue;
            }

            const cmp = Cmp.parse(parts[pos]);

            pos += 1;
            beg = pos;
            while (pos < parts.len and std.ascii.isDigit(parts[pos])) : (pos += 1) {}
            const value = try std.fmt.parseUnsigned(usize, parts[beg..pos], 10);

            pos += 1;
            beg = pos;
            while (pos < parts.len and std.ascii.isAlphabetic(parts[pos])) : (pos += 1) {}
            const dest = parts[beg..pos];
            const sp = try self.strtab.add(dest);
            const category = Category.parse(what[0]);
            var rule = Rule.init(category, cmp, value, sp);
            try workflow.rules.append(rule);
        }

        const sp = try self.strtab.add(name);
        try self.workflows.put(sp, workflow);
    }

    pub fn getRatingsForAcceptedParts(self: *Engine) usize {
        var total: usize = 0;
        for (self.parts.items) |part| {
            total += self.runPart(part);
        }
        return total;
    }

    pub fn getTotalRatings(self: *Engine) !usize {
        var initial_group = RangeGroup.init(self.allocator);
        defer initial_group.deinit();
        try self.findAllRanges(self.strtab.get_pos(STARTING_WORKFLOW).?, &initial_group);

        var total: usize = 0;
        for (self.ranges.items) |ranges| {
            var top = Part.init();
            var bot = Part.init();
            for (std.meta.tags(Category)) |c| {
                top.setRating(c, 4001);
                bot.setRating(c, 0);
            }

            for (ranges.items) |range| {
                switch (range.cmp) {
                    .LT => {
                        const tr = top.getRating(range.category);
                        if (range.value < tr) top.setRating(range.category, range.value);
                    },
                    .GT => {
                        const br = bot.getRating(range.category);
                        if (range.value > br) bot.setRating(range.category, range.value);
                    },
                }
            }

            var prod: usize = 1;
            for (std.meta.tags(Category)) |c| {
                prod *= top.getRating(c) - bot.getRating(c) - 1;
            }
            total += prod;
        }
        return total;
    }

    fn isAction(self: Engine, pos: StringId, wanted: []const u8) bool {
        const action = self.strtab.get_str(pos) orelse "";
        return std.mem.eql(u8, action, wanted);
    }

    fn isActionAccept(self: Engine, pos: StringId) bool {
        return self.isAction(pos, ACTION_ACCEPT);
    }

    fn isActionReject(self: Engine, pos: StringId) bool {
        return self.isAction(pos, ACTION_REJECT);
    }

    fn runPart(self: *Engine, part: Part) usize {
        var state = self.strtab.get_pos(STARTING_WORKFLOW).?;
        while (true) {
            const workflow = self.workflows.get(state).?;
            const next = workflow.run(part);
            if (self.isActionAccept(next)) {
                return part.getTotalRating();
            }
            if (self.isActionReject(next)) {
                return 0;
            }
            state = next;
        }
    }

    fn findAllRanges(self: *Engine, current: StringId, rules: *RangeGroup) !void {
        if (self.isActionReject(current)) return;
        if (self.isActionAccept(current)) {
            try self.ranges.append(try rules.*.clone());
            return;
        }

        var local_rg = RangeGroup.init(self.allocator);
        defer local_rg.deinit();
        try local_rg.appendSlice(rules.items);

        const workflow = self.workflows.get(current).?;
        for (workflow.rules.items) |rule| {
            try local_rg.append(rule.range);
            try self.findAllRanges(rule.target, &local_rg);
            _ = local_rg.pop();

            const range = switch (rule.range.cmp) {
                .LT => Range.init(rule.range.category, .GT, rule.range.value - 1),
                .GT => Range.init(rule.range.category, .LT, rule.range.value + 1),
            };
            try local_rg.append(range);
        }

        try self.findAllRanges(workflow.default, &local_rg);
    }
};

test "sample simple part 1" {
    const data =
        \\px{a<2006:qkq,m>2090:A,rfg}
        \\pv{a>1716:R,A}
        \\lnx{m>1548:A,A}
        \\rfg{s<537:gd,x>2440:R,A}
        \\qs{s>3448:A,lnx}
        \\qkq{x<1416:A,crn}
        \\crn{x>2662:A,R}
        \\in{s<1351:px,qqz}
        \\qqz{s>2770:qs,m<1801:hdj,R}
        \\gd{a>3333:R,R}
        \\hdj{m>838:A,pv}
        \\
        \\{x=787,m=2655,a=1222,s=2876}
        \\{x=1679,m=44,a=2067,s=496}
        \\{x=2036,m=264,a=79,s=2244}
        \\{x=2461,m=1339,a=466,s=291}
        \\{x=2127,m=1623,a=2188,s=1013}
    ;

    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try engine.addLine(line);
    }

    const count = engine.getRatingsForAcceptedParts();
    const expected = @as(usize, 19114);
    try testing.expectEqual(expected, count);
}

test "sample simple part 2" {
    const data =
        \\px{a<2006:qkq,m>2090:A,rfg}
        \\pv{a>1716:R,A}
        \\lnx{m>1548:A,A}
        \\rfg{s<537:gd,x>2440:R,A}
        \\qs{s>3448:A,lnx}
        \\qkq{x<1416:A,crn}
        \\crn{x>2662:A,R}
        \\in{s<1351:px,qqz}
        \\qqz{s>2770:qs,m<1801:hdj,R}
        \\gd{a>3333:R,R}
        \\hdj{m>838:A,pv}
        \\
        \\{x=787,m=2655,a=1222,s=2876}
        \\{x=1679,m=44,a=2067,s=496}
        \\{x=2036,m=264,a=79,s=2244}
        \\{x=2461,m=1339,a=466,s=291}
        \\{x=2127,m=1623,a=2188,s=1013}
    ;

    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try engine.addLine(line);
    }

    const count = try engine.getTotalRatings();
    const expected = @as(usize, 167409079868000);
    try testing.expectEqual(expected, count);
}
