const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const ValueType = enum {
    New,
    Old,
    Num,
};

pub const Value = union(ValueType) {
    New: void,
    Old: void,
    Num: usize,

    pub fn parse(str: []const u8) Value {
        if (std.mem.eql(u8, str, "new")) return .New;
        if (std.mem.eql(u8, str, "old")) return .Old;
        if (std.fmt.parseInt(usize, str, 10)) |num| {
            return Value{.Num = num};
        } else |_| {
            unreachable;
        }
    }
};

pub const OperationType = enum {
    Plus,
    Times,

    pub fn parse(str: []const u8) OperationType {
        if (std.mem.eql(u8, str, "+")) return .Plus;
        if (std.mem.eql(u8, str, "*")) return .Times;
        unreachable;
    }
};

pub const Operation = struct {
    op: OperationType,
    l: Value,
    r: Value,

    pub fn init(op: OperationType, l: Value, r: Value) Operation {
        var self = Operation{
            .op = op,
            .l = l,
            .r = r,
        };
        return self;
    }

    pub fn run(self: Operation, old: usize, super_modulo: usize) usize {
        const nl = switch(self.l) {
            .New => unreachable,
            .Old => old,
            .Num => |num| num,
        } % super_modulo;
        const nr = switch(self.r) {
            .New => unreachable,
            .Old => old,
            .Num => |num| num,
        } % super_modulo;
        const res = switch(self.op) {
            .Plus => nl + nr,
            .Times => nl * nr,
        };
        return res % super_modulo;
    }
};

pub const CheckDivisible = struct {
    value: usize,

    pub fn init(value: usize) CheckDivisible {
        var self = CheckDivisible{
            .value = value,
        };
        return self;
    }

    pub fn run(self: CheckDivisible, value: usize) bool {
        return value % self.value == 0;
    }
};

pub const Monkey = struct {
    items: std.ArrayList(usize),
    head: usize,
    operation: Operation,
    check: CheckDivisible,
    action_true: usize,
    action_false: usize,
    total_inspected: usize,

    pub fn init(allocator: Allocator) Monkey {
        var self = Monkey{
            .items = std.ArrayList(usize).init(allocator),
            .head = 0,
            .operation = undefined,
            .check = undefined,
            .action_true = undefined,
            .action_false = undefined,
            .total_inspected = 0,
        };
        return self;
    }

    pub fn deinit(self: *Monkey) void {
        self.items.deinit();
    }

    pub fn run(self: *Monkey, troop: *Troop) !void {
        var j: usize = self.head;
        while (j < self.items.items.len) : (j += 1) {
            var item = self.items.items[j];
            self.total_inspected += 1;
            var worry = self.operation.run(item, troop.super_modulo);
            worry /= troop.divider;
            var check = self.check.run(worry);
            var destination = if (check) self.action_true else self.action_false;
            try troop.add_item_to_monkey(destination, worry);
        }
        self.head = self.items.items.len;
    }
};

pub const Troop = struct {
    allocator: Allocator,
    monkeys: std.ArrayList(Monkey),
    monkey_count: usize,
    divider: usize,
    super_modulo: usize,

    pub fn init(allocator: Allocator, divider: usize) Troop {
        var self = Troop{
            .allocator = allocator,
            .monkeys = std.ArrayList(Monkey).init(allocator),
            .monkey_count = 0,
            .divider = divider,
            .super_modulo = 1,
        };
        return self;
    }

    pub fn deinit(self: *Troop) void {
        for (self.monkeys.items) |*monkey| {
            monkey.deinit();
        }
        self.monkeys.deinit();
    }

    pub fn add_line(self: *Troop, line: []const u8) !void {
        if (line.len == 0) {
            self.monkey_count += 1;
            return;
        }
        var it = std.mem.tokenize(u8, line, " :,");
        const action = it.next().?;
        if (std.mem.eql(u8, action, "Monkey")) {
            const num = try std.fmt.parseInt(usize, it.next().?, 10);
            if (num != self.monkey_count) unreachable;
            try self.monkeys.append(Monkey.init(self.allocator));
            return;
        }
        if (std.mem.eql(u8, action, "Starting")) {
            _ = it.next(); // items
            while (it.next()) |str| {
                const num = try std.fmt.parseInt(usize, str, 10);
                try self.monkeys.items[self.monkey_count].items.append(num);
            }
            return;
        }
        if (std.mem.eql(u8, action, "Operation")) {
            _ = Value.parse(it.next().?); // new
            _ = it.next(); // =
            var l = Value.parse(it.next().?);
            var op = OperationType.parse(it.next().?);
            var r = Value.parse(it.next().?);
            self.monkeys.items[self.monkey_count].operation = Operation.init(op, l, r);
            return;
        }
        if (std.mem.eql(u8, action, "Test")) {
            _ = it.next(); // divisible
            _ = it.next(); // by
            const num = try std.fmt.parseInt(usize, it.next().?, 10);
            self.monkeys.items[self.monkey_count].check = CheckDivisible.init(num);
            self.super_modulo *= num;
            return;
        }
        if (std.mem.eql(u8, action, "If")) {
            const which = it.next().?;
            _ = it.next(); // throw
            _ = it.next(); // to
            _ = it.next(); // monkey
            const num = try std.fmt.parseInt(usize, it.next().?, 10);
            if (std.mem.eql(u8, which, "true")) {
                self.monkeys.items[self.monkey_count].action_true = num;
            }
            if (std.mem.eql(u8, which, "false")) {
                self.monkeys.items[self.monkey_count].action_false = num;
            }
            return;
        }
    }

    pub fn add_item_to_monkey(self: *Troop, destination: usize, worry: usize) !void {
        try self.monkeys.items[destination].items.append(worry);
    }

    pub fn run_round_all_monkeys(self: *Troop) !void {
        for (self.monkeys.items) |*monkey| {
            try monkey.run(self);
        }
    }

    pub fn run_for_rounds(self: *Troop, rounds: usize) !void {
        var r: usize = 0;
        while (r < rounds) : (r += 1) {
            try self.run_round_all_monkeys();
        }
    }

    pub fn monkey_business(self: *Troop) !usize {
        var total_inspected = std.ArrayList(usize).init(self.allocator);
        defer total_inspected.deinit();
        for (self.monkeys.items) |monkey| {
            try total_inspected.append(monkey.total_inspected);
        }
        std.sort.sort(usize, total_inspected.items, {}, std.sort.desc(usize));
        return total_inspected.items[0] * total_inspected.items[1];
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\Monkey 0:
        \\  Starting items: 79, 98
        \\  Operation: new = old * 19
        \\  Test: divisible by 23
        \\    If true: throw to monkey 2
        \\    If false: throw to monkey 3
        \\
        \\Monkey 1:
        \\  Starting items: 54, 65, 75, 74
        \\  Operation: new = old + 6
        \\  Test: divisible by 19
        \\    If true: throw to monkey 2
        \\    If false: throw to monkey 0
        \\
        \\Monkey 2:
        \\  Starting items: 79, 60, 97
        \\  Operation: new = old * old
        \\  Test: divisible by 13
        \\    If true: throw to monkey 1
        \\    If false: throw to monkey 3
        \\
        \\Monkey 3:
        \\  Starting items: 74
        \\  Operation: new = old + 3
        \\  Test: divisible by 17
        \\    If true: throw to monkey 0
        \\    If false: throw to monkey 1
    ;

    var troop = Troop.init(std.testing.allocator, 3);
    defer troop.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try troop.add_line(line);
    }

    try troop.run_for_rounds(20);
    const mb = try troop.monkey_business();
    try testing.expectEqual(mb, 10605);
}

test "sample part 2" {
    const data: []const u8 =
        \\Monkey 0:
        \\  Starting items: 79, 98
        \\  Operation: new = old * 19
        \\  Test: divisible by 23
        \\    If true: throw to monkey 2
        \\    If false: throw to monkey 3
        \\
        \\Monkey 1:
        \\  Starting items: 54, 65, 75, 74
        \\  Operation: new = old + 6
        \\  Test: divisible by 19
        \\    If true: throw to monkey 2
        \\    If false: throw to monkey 0
        \\
        \\Monkey 2:
        \\  Starting items: 79, 60, 97
        \\  Operation: new = old * old
        \\  Test: divisible by 13
        \\    If true: throw to monkey 1
        \\    If false: throw to monkey 3
        \\
        \\Monkey 3:
        \\  Starting items: 74
        \\  Operation: new = old + 3
        \\  Test: divisible by 17
        \\    If true: throw to monkey 0
        \\    If false: throw to monkey 1
    ;

    var troop = Troop.init(std.testing.allocator, 1);
    defer troop.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try troop.add_line(line);
    }

    try troop.run_for_rounds(10_000);
    const mb = try troop.monkey_business();
    try testing.expectEqual(mb, 2713310158);
}
