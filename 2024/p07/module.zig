const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const Value = struct {
        val: usize,
        mul: usize,

        pub fn init(val: usize) Value {
            return .{ .val = val, .mul = std.math.pow(usize, 10, std.math.log10(val) + 1) };
        }
    };

    const Equation = struct {
        values: std.ArrayList(Value),
        pub fn init(allocator: Allocator) Equation {
            const self = Equation{
                .values = std.ArrayList(Value).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Equation) void {
            self.values.deinit();
        }

        pub fn addValue(self: *Equation, value: usize) !void {
            try self.values.append(Value.init(value));
        }

        pub fn canBeMadeValid(self: Equation, options: usize) !bool {
            const len = self.values.items.len;
            if (len <= 0) return false;
            if (len <= 1) return true;

            const wanted = self.values.items[0].val;
            if (len <= 2) return wanted == self.values.items[1].val;

            const top = std.math.pow(usize, options, len - 2);
            for (0..top) |num| {
                var computed: usize = self.values.items[1].val;
                var mask = num;
                var pos: usize = 2;
                for (0..len - 2) |_| {
                    const bit = mask % options;
                    mask /= options;
                    switch (bit) {
                        0 => {
                            computed += self.values.items[pos].val;
                        },
                        1 => {
                            computed *= self.values.items[pos].val;
                        },
                        2 => {
                            computed *= self.values.items[pos].mul;
                            computed += self.values.items[pos].val;
                        },
                        else => return error.InvalidOp,
                    }
                    if (computed > wanted) {
                        // all operations are increasing
                        break;
                    }
                    pos += 1;
                }
                if (computed == wanted) {
                    return true;
                }
            }
            return false;
        }
    };

    allocator: Allocator,
    concat: bool,
    equations: std.ArrayList(Equation),

    pub fn init(allocator: Allocator, concat: bool) Module {
        const self = Module{
            .allocator = allocator,
            .concat = concat,
            .equations = std.ArrayList(Equation).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Module) void {
        for (self.equations.items) |*r| {
            r.*.deinit();
        }
        self.equations.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        var equation = Equation.init(self.allocator);
        var it = std.mem.tokenizeAny(u8, line, " :");
        while (it.next()) |chunk| {
            const value = try std.fmt.parseUnsigned(usize, chunk, 10);
            try equation.addValue(value);
        }
        try self.equations.append(equation);
    }

    pub fn getTotalCalibration(self: Module) !usize {
        const options: usize = if (self.concat) 3 else 2;
        var total: usize = 0;
        for (self.equations.items) |equation| {
            if (!try equation.canBeMadeValid(options)) continue;
            total += equation.values.items[0].val;
        }
        return total;
    }
};

test "sample part 1" {
    const data =
        \\190: 10 19
        \\3267: 81 40 27
        \\83: 17 5
        \\156: 15 6
        \\7290: 6 8 6 15
        \\161011: 16 10 13
        \\192: 17 8 14
        \\21037: 9 7 18 13
        \\292: 11 6 16 20
    ;

    var module = Module.init(testing.allocator, false);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const total = try module.getTotalCalibration();
    const expected = @as(usize, 3749);
    try testing.expectEqual(expected, total);
}

test "sample part 2" {
    const data =
        \\190: 10 19
        \\3267: 81 40 27
        \\83: 17 5
        \\156: 15 6
        \\7290: 6 8 6 15
        \\161011: 16 10 13
        \\192: 17 8 14
        \\21037: 9 7 18 13
        \\292: 11 6 16 20
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const total = try module.getTotalCalibration();
    const expected = @as(usize, 11387);
    try testing.expectEqual(expected, total);
}
