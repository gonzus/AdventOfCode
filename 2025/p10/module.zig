const std = @import("std");
const testing = std.testing;

// Solution for part two heavily inspired on Marcin Serwin's work:
// https://git.sr.ht/~marcin-serwin/aoc/tree/main/item/2025/10/main.zig

pub const Module = struct {
    const Machine = struct {
        const MAX_LIGHTS = 16; // required: 10
        const MAX_BUTTONS = 16; // required: 13
        const INFINITY = std.math.maxInt(i16);

        lights: usize,
        buttons: std.ArrayList(usize),
        joltages: std.ArrayList(i16),

        pub fn init() Machine {
            return .{
                .lights = 0,
                .buttons = .empty,
                .joltages = .empty,
            };
        }

        pub fn deinit(self: *Machine, alloc: std.mem.Allocator) void {
            self.joltages.deinit(alloc);
            self.buttons.deinit(alloc);
        }

        // pub fn show(self: Machine) void {
        //     std.debug.print("  Lights: {b}\n", .{self.lights});
        //     std.debug.print("  Buttons: {}\n", .{self.buttons.items.len});
        //     for (self.buttons.items) |b| {
        //         std.debug.print("    Button: {b}\n", .{b});
        //     }
        //     std.debug.print("  Joltages:", .{});
        //     for (self.joltages.items) |j| {
        //         std.debug.print(" {}", .{j});
        //     }
        //     std.debug.print("\n", .{});
        // }

        fn pushButtons(self: Machine, buttons: usize) usize {
            var state: usize = 0;
            var pos: usize = 0;
            var mask = buttons;
            while (mask > 0) : (pos += 1) {
                const bit = mask & 1;
                mask >>= 1;
                if (bit != 1) continue;
                state ^= self.buttons.items[pos];
            }
            return state;
        }

        fn getMinButtonPressesForLights(self: Machine) i16 {
            const num_buttons = self.buttons.items.len;
            const limit = @as(usize, 1) << @as(u6, @intCast(num_buttons));
            for (1..num_buttons + 1) |needed| {
                for (1..limit) |mask| {
                    if (@popCount(mask) != needed) continue;

                    const state = self.pushButtons(mask);
                    if (state != self.lights) continue;

                    return @intCast(needed);
                }
            }
            return 0;
        }

        fn getMinButtonPressesForJoltages(self: Machine) i16 {
            const num_buttons = self.buttons.items.len;
            var buttons: [MAX_BUTTONS][MAX_LIGHTS]i16 = undefined;
            for (0..num_buttons) |b| {
                buttons[b] = @splat(0);
                var pos: usize = 0;
                var mask = self.buttons.items[b];
                while (mask > 0) : (pos += 1) {
                    const bit = mask & 1;
                    mask >>= 1;
                    buttons[b][pos] = @intCast(bit);
                }
            }
            const needed = self.findButtonsForJoltages(
                buttons[0..num_buttons],
                self.joltages.items,
            );
            return needed;
        }

        fn findButtonsForJoltages(self: Machine, buttons: [][MAX_LIGHTS]i16, joltage: []i16) i16 {
            // std.debug.print("BUTTONS: {any}\n", .{buttons});
            // std.debug.print("JOLTAGE: {any}\n", .{joltage});
            const num_lights = self.joltages.items.len;
            var constraints: [MAX_BUTTONS]i16 = @splat(INFINITY);
            for (buttons, 0..) |button_full, i| {
                const button = button_full[0..num_lights];
                for (0..joltage.len) |j| {
                    if (button[j] > 0 and joltage[j] < constraints[i]) {
                        constraints[i] = joltage[j];
                    }
                }
                std.debug.assert(constraints[i] < INFINITY);
            }

            const bound = reduceViaGaussianElimination(buttons, joltage, &constraints);

            var top: i16 = INFINITY;
            for (0..arrayProduct(constraints[bound..buttons.len])) |i| {
                var sol = getInitialSolution(i, bound, constraints[0..buttons.len]);
                if (searchFromInitialSolution(buttons, joltage[0..bound], sol[0..buttons.len])) |clicks| {
                    if (top > clicks) {
                        top = clicks;
                    }
                }
            }
            std.debug.assert(top < INFINITY);
            return top;
        }

        fn reduceViaGaussianElimination(buttons: [][MAX_LIGHTS]i16, joltage: []i16, constraints: []i16) u32 {
            var skipped: u32 = 0;
            var bound: u32 = 0;
            for (0..@min(buttons.len, joltage.len)) |i| {
                const leading = while (true) {
                    break for (i..joltage.len) |j| {
                        if (buttons[i][j] != 0) {
                            break j;
                        }
                    } else {
                        skipped += 1;
                        if (i >= buttons.len - skipped) {
                            return bound;
                        }
                        std.mem.swap(
                            [MAX_LIGHTS]i16,
                            &buttons[i],
                            &buttons[buttons.len - skipped],
                        );
                        std.mem.swap(i16, &constraints[i], &constraints[buttons.len - skipped]);
                        continue;
                    };
                };
                bound += 1;
                if (i != leading) {
                    swapRows(buttons, i, leading, joltage);
                }

                for (i + 1..joltage.len) |j| {
                    if (buttons[i][j] != 0) {
                        subtractRows(buttons, i, j, joltage);
                    }
                }
            }

            return bound;
        }

        fn getInitialSolution(nth: usize, bound: u32, constraints: []i16) [MAX_BUTTONS]i16 {
            var sol: [MAX_BUTTONS]i16 = undefined;
            var n: i32 = @intCast(nth);
            for (bound..constraints.len) |i| {
                sol[i] = @intCast(@mod(n, constraints[i] + 1));
                n = @divFloor(n, constraints[i] + 1);
            }
            return sol;
        }

        fn searchFromInitialSolution(buttons: [][MAX_LIGHTS]i16, joltage: []i16, sol: []i16) ?i16 {
            var i = joltage.len;
            while (i > 0) {
                i -= 1;
                var j = buttons.len - 1;
                var val = joltage[i];
                while (j > i) {
                    val -= sol[j] * buttons[j][i];
                    j -= 1;
                }
                if (@rem(val, buttons[i][i]) != 0) {
                    return null;
                }
                sol[i] = @divExact(val, buttons[i][i]);
                if (sol[i] < 0) {
                    return null;
                }
            }
            var sum: i16 = 0;
            for (sol) |b| {
                sum += b;
            }
            return sum;
        }

        fn arrayProduct(arr: []i16) u32 {
            var res: u32 = 1;
            for (arr) |e| {
                res *= @intCast(e + 1);
            }
            return @intCast(res);
        }

        fn swapRows(buttons: [][MAX_LIGHTS]i16, i: usize, j: usize, joltage: []i16) void {
            std.mem.swap(i16, &joltage[i], &joltage[j]);
            for (0..buttons.len) |k| {
                std.mem.swap(i16, &buttons[k][i], &buttons[k][j]);
            }
        }

        fn subtractRows(buttons: [][MAX_LIGHTS]i16, i: usize, j: usize, joltage: []i16) void {
            const gcd: i16 = @intCast(std.math.gcd(
                @abs(buttons[i][i]),
                @abs(buttons[i][j]),
            ));
            const a = @divExact(buttons[i][i], gcd);
            const b = @divExact(buttons[i][j], gcd);
            joltage[j] *= a;
            joltage[j] -= joltage[i] * b;
            for (0..buttons.len) |k| {
                buttons[k][j] *= a;
                buttons[k][j] -= buttons[k][i] * b;
            }
        }
    };

    alloc: std.mem.Allocator,
    machines: std.ArrayList(Machine),

    pub fn init(alloc: std.mem.Allocator) Module {
        return .{
            .alloc = alloc,
            .machines = std.ArrayList(Machine).empty,
        };
    }

    pub fn deinit(self: *Module) void {
        for (self.machines.items) |*m| {
            m.deinit(self.alloc);
        }
        self.machines.deinit(self.alloc);
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        var its = std.mem.tokenizeScalar(u8, line, ' ');
        var m = Machine.init();
        while (its.next()) |chunk| {
            if (chunk[0] == '[') {
                const str = chunk[1 .. chunk.len - 1];
                var mask: usize = 1;
                for (str) |c| {
                    if (c == '#') {
                        m.lights |= mask;
                    }
                    mask <<= 1;
                }
                continue;
            }
            if (chunk[0] == '(') {
                const str = chunk[1 .. chunk.len - 1];
                var mask: usize = 0;
                var it = std.mem.tokenizeScalar(u8, str, ',');
                while (it.next()) |s| {
                    const n = try std.fmt.parseUnsigned(u6, s, 10);
                    mask |= @as(usize, 1) << n;
                }
                try m.buttons.append(self.alloc, mask);
                continue;
            }
            if (chunk[0] == '{') {
                const str = chunk[1 .. chunk.len - 1];
                var it = std.mem.tokenizeScalar(u8, str, ',');
                while (it.next()) |s| {
                    const j = try std.fmt.parseInt(i16, s, 10);
                    try m.joltages.append(self.alloc, j);
                }
                continue;
            }
        }
        try self.machines.append(self.alloc, m);
    }

    // pub fn show(self: Module) void {
    //     std.debug.print("Machines: {}\n", .{self.machines.items.len});
    //     for (0..self.machines.items.len) |m| {
    //         std.debug.print("Machine #{}:\n", .{m});
    //         const machine = self.machines.items[m];
    //         machine.show();
    //     }
    // }

    pub fn getTotalButtonPressesForLights(self: Module) !i16 {
        var total: i16 = 0;
        for (self.machines.items) |machine| {
            const needed = machine.getMinButtonPressesForLights();
            total += needed;
        }
        return total;
    }

    pub fn getTotalButtonPressesForJoltages(self: Module) !i16 {
        var total: i16 = 0;
        for (self.machines.items) |machine| {
            const needed = machine.getMinButtonPressesForJoltages();
            total += needed;
        }
        return total;
    }
};

test "sample part 1" {
    const data =
        \\[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}
        \\[...#.] (0,2,3,4) (2,3) (0,4) (0,1,2) (1,2,3,4) {7,5,12,7,2}
        \\[.###.#] (0,1,2,3,4) (0,3,4) (0,1,2,4,5) (1,2) {10,11,11,5,10,5}
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |line| {
        try module.addLine(line);
    }
    // module.show();

    const product = try module.getTotalButtonPressesForLights();
    const expected = @as(i16, 7);
    try testing.expectEqual(expected, product);
}

test "sample part 2" {
    const data =
        \\[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}
        \\[...#.] (0,2,3,4) (2,3) (0,4) (0,1,2) (1,2,3,4) {7,5,12,7,2}
        \\[.###.#] (0,1,2,3,4) (0,3,4) (0,1,2,4,5) (1,2) {10,11,11,5,10,5}
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |line| {
        try module.addLine(line);
    }
    // module.show();

    const product = try module.getTotalButtonPressesForJoltages();
    const expected = @as(i16, 33);
    try testing.expectEqual(expected, product);
}
