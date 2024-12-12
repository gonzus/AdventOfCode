const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const COST_A: isize = 3;
    const COST_B: isize = 1;
    const DELTA_PRIZE: isize = 10000000000000;

    const Machine = struct {
        button_a_x: isize,
        button_a_y: isize,
        button_b_x: isize,
        button_b_y: isize,
        prize_x: isize,
        prize_y: isize,

        pub fn init() Machine {
            return .{
                .button_a_x = 0,
                .button_a_y = 0,
                .button_b_x = 0,
                .button_b_y = 0,
                .prize_x = 0,
                .prize_y = 0,
            };
        }
    };

    delta: bool,
    machines: std.ArrayList(Machine),

    pub fn init(allocator: Allocator, delta: bool) Module {
        return .{
            .delta = delta,
            .machines = std.ArrayList(Machine).init(allocator),
        };
    }

    pub fn deinit(self: *Module) void {
        self.machines.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        if (line.len == 0) return;

        var itl = std.mem.tokenizeAny(u8, line, ":");
        const l = itl.next().?;
        const r = itl.next().?;
        var p: usize = 0;
        var x: isize = 0;
        var y: isize = 0;
        var itp = std.mem.tokenizeAny(u8, r, ", ");
        while (itp.next()) |v| : (p += 1) {
            const n = try std.fmt.parseInt(isize, v[2..], 10);
            switch (p) {
                0 => x = n,
                1 => y = n,
                else => return error.TooManyValues,
            }
        }
        var pos = self.machines.items.len;
        if (std.mem.eql(u8, l, "Button A")) {
            try self.machines.append(Machine.init());
            self.machines.items[pos].button_a_x = x;
            self.machines.items[pos].button_a_y = y;
            return;
        }
        pos -= 1;
        if (std.mem.eql(u8, l, "Button B")) {
            self.machines.items[pos].button_b_x = x;
            self.machines.items[pos].button_b_y = y;
            return;
        }
        if (std.mem.eql(u8, l, "Prize")) {
            self.machines.items[pos].prize_x = x;
            self.machines.items[pos].prize_y = y;
            return;
        }
        return error.InvalidLine;
    }

    // pub fn show(self: Module) void {
    //     const delta = self.getDelta();
    //     std.debug.print("Machines: {}\n", .{self.machines.items.len});
    //     for (self.machines.items, 0..) |m, p| {
    //         if (p > 0) {
    //             std.debug.print("\n", .{});
    //         }
    //         std.debug.print("{}: Button A: X+{}, Y+{}\n", .{ p, m.button_a_x, m.button_a_y });
    //         std.debug.print("{}: Button B: X+{}, Y+{}\n", .{ p, m.button_b_x, m.button_b_y });
    //         std.debug.print("{}: Prize: X={}, Y={}\n", .{ p, m.prize_x + delta, m.prize_y + delta });
    //     }
    // }

    pub fn getFewestTokens(self: *Module) !usize {
        // self.show();
        var tokens: usize = 0;
        for (self.machines.items) |m| {
            const prize_x = m.prize_x + self.getDelta();
            const prize_y = m.prize_y + self.getDelta();
            const det_m = m.button_a_x * m.button_b_y - m.button_b_x * m.button_a_y;

            const det_a = prize_x * m.button_b_y - m.button_b_x * prize_y;
            if (@mod(det_a, det_m) != 0) continue;

            const det_b = m.button_a_x * prize_y - prize_x * m.button_a_y;
            if (@mod(det_b, det_m) != 0) continue;

            const push_a = @divTrunc(det_a, det_m);
            const push_b = @divTrunc(det_b, det_m);
            const spent = push_a * COST_A + push_b * COST_B;
            // std.debug.print("push_a = {}, push_b = {}, spent = {}\n", .{ push_a, push_b, spent });
            tokens += @intCast(spent);
        }
        return tokens;
    }

    fn getDelta(self: Module) isize {
        return if (self.delta) DELTA_PRIZE else 0;
    }
};

test "sample part 1" {
    const data =
        \\Button A: X+94, Y+34
        \\Button B: X+22, Y+67
        \\Prize: X=8400, Y=5400
        \\
        \\Button A: X+26, Y+66
        \\Button B: X+67, Y+21
        \\Prize: X=12748, Y=12176
        \\
        \\Button A: X+17, Y+86
        \\Button B: X+84, Y+37
        \\Prize: X=7870, Y=6450
        \\
        \\Button A: X+69, Y+23
        \\Button B: X+27, Y+71
        \\Prize: X=18641, Y=10279
    ;

    var module = Module.init(testing.allocator, false);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getFewestTokens();
    const expected = @as(usize, 480);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\Button A: X+94, Y+34
        \\Button B: X+22, Y+67
        \\Prize: X=8400, Y=5400
        \\
        \\Button A: X+26, Y+66
        \\Button B: X+67, Y+21
        \\Prize: X=12748, Y=12176
        \\
        \\Button A: X+17, Y+86
        \\Button B: X+84, Y+37
        \\Prize: X=7870, Y=6450
        \\
        \\Button A: X+69, Y+23
        \\Button B: X+27, Y+71
        \\Prize: X=18641, Y=10279
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.getFewestTokens();
    const expected = @as(usize, 875318608908);
    try testing.expectEqual(expected, count);
}
