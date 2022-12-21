const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;
const StringTable = @import("./util/strtab.zig").StringTable;

pub const Riddle = struct {
    const NOBODY = std.math.maxInt(usize);

    const OpTag = enum(u8) {
        ADD = '+',
        SUB = '-',
        MUL = '*',
        DIV = '/',

        pub fn parse(what: []const u8) OpTag {
            if (std.mem.eql(u8, what, "+")) return .ADD;
            if (std.mem.eql(u8, what, "-")) return .SUB;
            if (std.mem.eql(u8, what, "*")) return .MUL;
            if (std.mem.eql(u8, what, "/")) return .DIV;
            unreachable;
        }
    };

    const Expression = struct {
        op: OpTag,
        l: usize,
        r: usize,
    };

    const ActionTag = enum {
        Number,
        Formula,
    };

    const Action = union(ActionTag) {
        Number: f64,
        Formula: Expression,
    };

    allocator: Allocator,
    strings: StringTable,
    monkeys: std.AutoHashMap(usize, Action),

    pub fn init(allocator: Allocator) Riddle {
        var self = Riddle{
            .allocator = allocator,
            .strings = StringTable.init(allocator),
            .monkeys = std.AutoHashMap(usize, Action).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Riddle) void {
        self.monkeys.deinit();
        self.strings.deinit();
    }

    pub fn add_line(self: *Riddle, line: []const u8) !void {
        var it = std.mem.tokenize(u8, line, ": ");
        var action: Action = undefined;
        const name = it.next().?; // monkey name
        const ls = it.next().?; // left operand
        if (ls[0] < '0' or ls[0] > '9') {
            const os = it.next().?; // operation
            const rs = it.next().?; // right operand
            const op = OpTag.parse(os);
            const ln = self.strings.add(ls);
            const rn = self.strings.add(rs);
            const expression = Expression{.op = op, .l = ln, .r = rn};
            action = Action{.Formula = expression};
        } else {
            const num = try std.fmt.parseFloat(f64, ls);
            action = Action{.Number = num};
        }
        const monkey = self.strings.add(name);
        try self.monkeys.put(monkey, action);
    }

    pub fn show(self: Riddle) void {
        var it = self.monkeys.iterator();
        while (it.next()) |e| {
            const name = self.strings.get_str(e.key_ptr.*).?;
            std.debug.print("Monkey {s} => ", .{name});
            const action = e.value_ptr.*;
            switch (action) {
                .Number => |n| std.debug.print("{d:.0}\n", .{n}),
                .Formula => |f| {
                    const ln = self.strings.get_str(f.l).?;
                    const rn = self.strings.get_str(f.r).?;
                    std.debug.print("{s} {c} {s}\n", .{ln, @enumToInt(f.op), rn});
                },
            }
        }
    }

    fn eval_monkey(self: *Riddle, monkey: usize, human: usize, exception: f64) f64 {
        if (monkey == human) return exception;
        const action = self.monkeys.get(monkey).?;
        switch (action) {
            .Number => |n| return n,
            .Formula => |f| {
                const l = self.eval_monkey(f.l, human, exception);
                const r = self.eval_monkey(f.r, human, exception);
                return switch (f.op) {
                    .ADD => l + r,
                    .SUB => l - r,
                    .MUL => l * r,
                    .DIV => l / r,
                };
            },
        }
        return 0;
    }

    pub fn solve_for_root(self: *Riddle) !f64 {
        const root = self.strings.get_pos("root").?;
        return self.eval_monkey(root, NOBODY, 0);
    }

    pub fn search_for_human(self: *Riddle) !f64 {
        const human = self.strings.get_pos("humn").?;
        const root = self.strings.get_pos("root").?;
        const action = self.monkeys.get(root).?;
        const monkey_l = action.Formula.l;
        const monkey_r = action.Formula.r;

        // we will do an open-ended binary search
        // first we need to find a suitable upper limit
        var g0: f64 = 1; // lower limit
        var l0 = self.eval_monkey(monkey_l, human, g0);
        var r0 = self.eval_monkey(monkey_r, human, g0);
        var g1 = g0;
        var l1 = l0;
        var r1 = r0;
        while (true) {
            if (l0 < r0 and l1 > r1) break;
            if (l0 > r0 and l1 < r1) break;
            g1 *= 10;
            l1 = self.eval_monkey(monkey_l, human, g1);
            r1 = self.eval_monkey(monkey_r, human, g1);
        }

        if (l0 < r0 and l1 > r1) {
            // std.debug.print("GOOD 1: {d:.0} {d:.0} and {d:.0} {d:.0}\n", .{l0, r0, l1, r1});
            while (true) {
                const g: f64 = (g0 + g1) / 2;
                const l = self.eval_monkey(monkey_l, human, g);
                const r = self.eval_monkey(monkey_r, human, g);
                // std.debug.print("GUESS 1: {d:.0} -> {d:.0} {d:.0}\n", .{g, l, r});
                if (l < r) { g0 = g + 1; continue; }
                if (l > r) { g1 = g - 1; continue; }
                return g;
            }
        }

        if (l0 > r0 and l1 < r1) {
            // std.debug.print("GOOD 2: {d:.0} {d:.0} and {d:.0} {d:.0}\n", .{l0, r0, l1, r1});
            while (true) {
                const g: f64 = (g0 + g1) / 2;
                const l = self.eval_monkey(monkey_l, human, g);
                const r = self.eval_monkey(monkey_r, human, g);
                // std.debug.print("GUESS 2: {d:.0} -> {d:.0} {d:.0}\n", .{g, l, r});
                if (l < r) { g1 = g - 1; continue; }
                if (l > r) { g0 = g + 1; continue; }
                return g;
            }
        }

        std.debug.print("Range {d:.0} - {d:.0} was too small?\n", .{g0, g1});
        return 0;
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\root: pppw + sjmn
        \\dbpl: 5
        \\cczh: sllz + lgvd
        \\zczc: 2
        \\ptdq: humn - dvpt
        \\dvpt: 3
        \\lfqf: 4
        \\humn: 5
        \\ljgn: 2
        \\sjmn: drzm * dbpl
        \\sllz: 4
        \\pppw: cczh / lfqf
        \\lgvd: ljgn * ptdq
        \\drzm: hmdt - zczc
        \\hmdt: 32
    ;

    var riddle = Riddle.init(std.testing.allocator);
    defer riddle.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try riddle.add_line(line);
    }
    // riddle.show();

    const answer = try riddle.solve_for_root();
    try testing.expectEqual(@as(f64, 152), answer);
}

test "sample part 2" {
    const data: []const u8 =
        \\root: pppw + sjmn
        \\dbpl: 5
        \\cczh: sllz + lgvd
        \\zczc: 2
        \\ptdq: humn - dvpt
        \\dvpt: 3
        \\lfqf: 4
        \\humn: 5
        \\ljgn: 2
        \\sjmn: drzm * dbpl
        \\sllz: 4
        \\pppw: cczh / lfqf
        \\lgvd: ljgn * ptdq
        \\drzm: hmdt - zczc
        \\hmdt: 32
    ;

    var riddle = Riddle.init(std.testing.allocator);
    defer riddle.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try riddle.add_line(line);
    }
    // riddle.show();

    const answer = try riddle.search_for_human();
    try testing.expectEqual(@as(f64, 301), answer);
}
