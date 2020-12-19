const std = @import("std");
const testing = std.testing;
const StringTable = @import("./strtab.zig").StringTable;

const allocator = std.heap.page_allocator;

pub const Validator = struct {
    const Rule = struct {
        parts: std.ArrayList(usize),

        pub fn init() *Rule {
            var self = allocator.create(Rule) catch unreachable;
            self.*.parts = std.ArrayList(usize).init(allocator);
            return self;
        }

        pub fn deinit(self: *Rule) void {
            self.parts.deinit();
        }
    };

    const RuleSet = struct {
        leaf: u8,
        rules: std.ArrayList(*Rule),

        pub fn init() *RuleSet {
            var self = allocator.create(RuleSet) catch unreachable;
            self.*.leaf = 0;
            self.*.rules = std.ArrayList(*Rule).init(allocator);
            return self;
        }

        pub fn deinit(self: *RuleSet) void {
            self.rules.deinit();
        }

        pub fn add_rule(self: *RuleSet, parts: []const usize) void {
            var rule = Rule.init();
            rule.*.parts.appendSlice(parts) catch unreachable;
            self.*.rules.append(rule) catch unreachable;
        }
    };

    rules: std.AutoHashMap(usize, *RuleSet),
    messages: std.ArrayList(usize),
    strings: StringTable,
    zone: usize,

    pub fn init() Validator {
        return Validator{
            .rules = std.AutoHashMap(usize, *RuleSet).init(allocator),
            .messages = std.ArrayList(usize).init(allocator),
            .strings = StringTable.init(allocator),
            .zone = 0,
        };
    }

    pub fn deinit(self: *Validator) void {
        self.strings.deinit();
        self.messages.deinit();
        self.rules.deinit();
    }

    pub fn add_line(self: *Validator, line: []const u8) void {
        if (line.len == 0) {
            self.zone += 1;
            return;
        }

        if (self.zone == 0) {
            var it_colon = std.mem.tokenize(line, ":");
            const code = std.fmt.parseInt(usize, it_colon.next().?, 10) catch unreachable;
            var ruleset = RuleSet.init();
            var it_pipe = std.mem.tokenize(it_colon.next().?, "|");
            PIPE: while (it_pipe.next()) |rules| {
                var it_space = std.mem.tokenize(rules, " ");
                var rule = Rule.init();
                while (it_space.next()) |r| {
                    if (r[0] == '"') {
                        rule.deinit();
                        ruleset.*.leaf = r[1];
                        break :PIPE;
                    }

                    const n = std.fmt.parseInt(usize, r, 10) catch unreachable;
                    rule.*.parts.append(n) catch unreachable;
                }
                ruleset.*.rules.append(rule) catch unreachable;
            }
            _ = self.rules.put(code, ruleset) catch unreachable;
            return;
        }
        if (self.zone == 1) {
            const code = self.strings.add(line);
            self.messages.append(code) catch unreachable;
            return;
        }
        @panic("ZONE");
    }

    pub fn show(self: Validator) void {
        std.debug.warn("---------------------\n", .{});
        std.debug.warn("Validator with {} rules\n", .{self.rules.count()});
        var its = self.rules.iterator();
        while (its.next()) |kvs| {
            const code = kvs.key;
            const rs = kvs.value;
            std.debug.warn("{}", .{code});
            if (rs.leaf > 0) {
                std.debug.warn(": \"{c}\"\n", .{rs.leaf});
                continue;
            }
            var pr: usize = 0;
            while (pr < rs.rules.items.len) : (pr += 1) {
                const sep: []const u8 = if (pr == 0) ":" else " |";
                std.debug.warn("{}", .{sep});
                const r = rs.rules.items[pr];
                const parts = r.parts;
                var pp: usize = 0;
                while (pp < parts.items.len) : (pp += 1) {
                    std.debug.warn(" {}", .{parts.items[pp]});
                }
            }
            std.debug.warn("\n", .{});
        }
    }

    // match against a complex ruleset, that is, against any of the sets of
    // rules separated by "|"
    fn match_complex_ruleset(self: *Validator, level: usize, str: []const u8, ruleset: *RuleSet, stack: *std.ArrayList(usize)) bool {
        var match = false;
        const rules = ruleset.rules.items;

        // any of the sets of rules in a ruleset could match, try them all
        var pr: usize = 0;
        while (!match and pr < rules.len) : (pr += 1) {
            // clone stack
            var copy = std.ArrayList(usize).init(allocator);
            defer copy.deinit();
            copy.appendSlice(stack.items) catch unreachable;

            // add all parts of current rule, in reverse order
            const rule = rules[pr];
            const parts = rule.parts.items;
            var pp: usize = 0;
            while (pp < parts.len) : (pp += 1) {
                const cs = parts[parts.len - 1 - pp];
                copy.append(cs) catch unreachable;
            }

            // try to match with current rule
            match = self.match_rule(level + 1, str, &copy);
        }

        return match;
    }

    // match against a leaf ruleset, that is, one defined as a single "X" character
    fn match_leaf_ruleset(self: *Validator, level: usize, str: []const u8, ruleset: *RuleSet, stack: *std.ArrayList(usize)) bool {
        const match = str[0] == ruleset.leaf;

        // if it doesn't match the leaf character, we are busted
        if (!match) return false;

        // clone stack
        var copy = std.ArrayList(usize).init(allocator);
        defer copy.deinit();
        copy.appendSlice(stack.items) catch unreachable;

        // this leaf matches, try to match rest of string with rest of rules
        return self.match_rule(level + 1, str[1..], &copy);
    }

    // match against a single rule, consuming both characters from the string
    // and pending rules to be matched
    fn match_rule(self: *Validator, level: usize, str: []const u8, stack: *std.ArrayList(usize)) bool {
        // not enough pending rules, given the length of the remaining string
        if (stack.items.len > str.len) return false;

        // if we ran out of pending rules OR characters in the string:
        // return true if we ran out of BOTH at the same time
        if (stack.items.len == 0 or str.len == 0)
            return stack.items.len == 0 and str.len == 0;

        // pop the first pending rule from the stack and try to match against that
        // of course, successive attempts will not use this popped rule anymore
        const cs = stack.pop();
        const ruleset = self.rules.get(cs).?;
        var match = false;
        if (ruleset.leaf > 0) {
            match = self.match_leaf_ruleset(level, str, ruleset, stack);
        } else {
            match = self.match_complex_ruleset(level, str, ruleset, stack);
        }
        return match;
    }

    pub fn count_valid(self: *Validator) usize {
        var count: usize = 0;
        var pm: usize = 0;
        while (pm < self.messages.items.len) : (pm += 1) {
            const cm = self.messages.items[pm];
            const message = self.strings.get_str(cm).?;

            // we need a stack of pending rules to match; initially empty
            var stack = std.ArrayList(usize).init(allocator);
            defer stack.deinit();

            // we will start matching against rule 0
            const ruleset = self.rules.get(0).?;

            const match = self.match_complex_ruleset(0, message, ruleset, &stack);
            if (match) count += 1;
        }
        return count;
    }

    pub fn fixup_rules(self: *Validator) void {
        const parts8 = [_]usize{ 42, 8 };
        self.rules.get(8).?.add_rule(parts8[0..]);

        const parts11 = [_]usize{ 42, 11, 31 };
        self.rules.get(11).?.add_rule(parts11[0..]);
    }
};

test "sample part a" {
    const data: []const u8 =
        \\0: 4 1 5
        \\1: 2 3 | 3 2
        \\2: 4 4 | 5 5
        \\3: 4 5 | 5 4
        \\4: "a"
        \\5: "b"
        \\
        \\ababbb
        \\bababa
        \\abbbab
        \\aaabbb
        \\aaaabbb
    ;

    var validator = Validator.init();
    defer validator.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        validator.add_line(line);
    }

    const count = validator.count_valid();
    testing.expect(count == 2);
}

test "samples part b" {
    const data: []const u8 =
        \\42: 9 14 | 10 1
        \\9: 14 27 | 1 26
        \\10: 23 14 | 28 1
        \\1: "a"
        \\11: 42 31
        \\5: 1 14 | 15 1
        \\19: 14 1 | 14 14
        \\12: 24 14 | 19 1
        \\16: 15 1 | 14 14
        \\31: 14 17 | 1 13
        \\6: 14 14 | 1 14
        \\2: 1 24 | 14 4
        \\0: 8 11
        \\13: 14 3 | 1 12
        \\15: 1 | 14
        \\17: 14 2 | 1 7
        \\23: 25 1 | 22 14
        \\28: 16 1
        \\4: 1 1
        \\20: 14 14 | 1 15
        \\3: 5 14 | 16 1
        \\27: 1 6 | 14 18
        \\14: "b"
        \\21: 14 1 | 1 14
        \\25: 1 1 | 1 14
        \\22: 14 14
        \\8: 42
        \\26: 14 22 | 1 20
        \\18: 15 15
        \\7: 14 5 | 1 21
        \\24: 14 1
        \\
        \\abbbbbabbbaaaababbaabbbbabababbbabbbbbbabaaaa
        \\bbabbbbaabaabba
        \\babbbbaabbbbbabbbbbbaabaaabaaa
        \\aaabbbbbbaaaabaababaabababbabaaabbababababaaa
        \\bbbbbbbaaaabbbbaaabbabaaa
        \\bbbababbbbaaaaaaaabbababaaababaabab
        \\ababaaaaaabaaab
        \\ababaaaaabbbaba
        \\baabbaaaabbaaaababbaababb
        \\abbbbabbbbaaaababbbbbbaaaababb
        \\aaaaabbaabaaaaababaa
        \\aaaabbaaaabbaaa
        \\aaaabbaabbaaaaaaabbbabbbaaabbaabaaa
        \\babaaabbbaaabaababbaabababaaab
        \\aabbbbbaabbbaaaaaabbbbbababaaaaabbaaabba
    ;
    {
        var validator = Validator.init();
        defer validator.deinit();

        var it = std.mem.split(data, "\n");
        while (it.next()) |line| {
            validator.add_line(line);
        }

        const count = validator.count_valid();
        testing.expect(count == 3);
    }
    {
        var validator = Validator.init();
        defer validator.deinit();

        var it = std.mem.split(data, "\n");
        while (it.next()) |line| {
            validator.add_line(line);
        }

        validator.fixup_rules();
        const count = validator.count_valid();
        testing.expect(count == 12);
    }
}

test "gonzo" {
    const data: []const u8 =
        \\0: 8 92
        \\8: 42
        \\11: 42 31
        \\42: "a"
        \\91: "a"
        \\92: "b"
        \\
        \\ab
        \\aab
    ;

    var validator = Validator.init();
    defer validator.deinit();

    var it = std.mem.split(data, "\n");
    while (it.next()) |line| {
        validator.add_line(line);
    }
    // validator.show();

    const count = validator.count_valid();
    testing.expect(count == 1);
}
