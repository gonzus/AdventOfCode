const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const INFINITY = std.math.maxInt(u128);
    const REGS = 3;

    const State = enum { register, program };

    const Opcode = enum(u8) {
        adv,
        bxl,
        bst,
        jnz,
        bxc,
        out,
        bdv,
        cdv,

        pub fn parse(n: u8) !Opcode {
            for (Opcodes) |o| {
                if (@intFromEnum(o) == n) return o;
            }
            return error.InvalidOpcode;
        }
    };
    const Opcodes = std.meta.tags(Opcode);

    const Probe = struct {
        len: usize,
        areg: u128,

        pub fn init(len: usize, areg: u128) Probe {
            return .{ .len = len, .areg = areg };
        }
    };

    state: State,
    orig: [REGS]u128,
    regs: [REGS]u128,
    program: std.ArrayList(u8),
    output: std.ArrayList(u8),
    fmt_buf: [1024]u8,
    fmt_len: usize,
    probes: std.ArrayList(Probe),

    pub fn init(allocator: Allocator) Module {
        return .{
            .state = .register,
            .orig = [_]u128{ 0, 0, 0 },
            .regs = [_]u128{ 0, 0, 0 },
            .program = std.ArrayList(u8).init(allocator),
            .output = std.ArrayList(u8).init(allocator),
            .fmt_buf = undefined,
            .fmt_len = 0,
            .probes = std.ArrayList(Probe).init(allocator),
        };
    }

    pub fn deinit(self: *Module) void {
        self.probes.deinit();
        self.output.deinit();
        self.program.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        if (line.len == 0) {
            self.state = .program;
            return;
        }
        switch (self.state) {
            .register => {
                var it = std.mem.tokenizeAny(u8, line, ": ");
                _ = it.next();
                const name = it.next().?;
                const value = it.next().?;
                const num = try std.fmt.parseUnsigned(u128, value, 10);
                self.orig[name[0] - 'A'] = num;
                self.regs[name[0] - 'A'] = num;
            },
            .program => {
                var it = std.mem.tokenizeAny(u8, line, ": ,");
                _ = it.next();
                while (it.next()) |chunk| {
                    try self.program.append(try std.fmt.parseUnsigned(u8, chunk, 10));
                }
            },
        }
    }

    // pub fn show(self: Module) void {
    //     std.debug.print("Computer with {} registers and {} bytes in program\n", .{ REGS, self.program.items.len });
    //     std.debug.print("Registers:\n", .{});
    //     for (0..REGS) |r| {
    //         const l: u8 = @intCast(r + 'A');
    //         std.debug.print("  {c} = {}\n", .{ l, self.regs[r] });
    //     }
    //     std.debug.print("Program:", .{});
    //     for (self.program.items) |p| {
    //         std.debug.print(" {}", .{p});
    //     }
    //     std.debug.print("\n", .{});
    // }

    pub fn getProgramOutput(self: *Module) ![]const u8 {
        // self.show();
        try self.run(INFINITY);

        self.fmt_len = 0;
        for (self.output.items, 0..) |o, p| {
            if (p > 0) {
                self.fmt_buf[self.fmt_len] = ',';
                self.fmt_len += 1;
            }
            const buf = try std.fmt.bufPrint(self.fmt_buf[self.fmt_len .. 1024 - self.fmt_len], "{}", .{o});
            self.fmt_len += buf.len;
        }
        return self.fmt_buf[0..self.fmt_len];
    }

    pub fn findQuine(self: *Module) !u128 {
        // self.show();
        var best: u128 = INFINITY;
        const prg = self.program.items;
        self.probes.clearRetainingCapacity();
        try self.probes.append(Probe.init(1, 0));
        var pos: usize = 0;
        while (pos < self.probes.items.len) : (pos += 1) {
            const probe = self.probes.items[pos];
            for (0..8) |len| {
                const areg = probe.areg + len;
                try self.run(areg);
                var tlen: usize = prg.len;
                if (tlen >= probe.len) {
                    tlen -= probe.len;
                }
                if (!std.mem.eql(u8, self.output.items, prg[tlen..prg.len])) continue;
                try self.probes.append(Probe.init(probe.len + 1, areg * 8));
                if (probe.len != self.program.items.len) continue;
                if (best > areg) {
                    best = areg;
                }
            }
        }
        return best;
    }

    fn run(self: *Module, regA: u128) !void {
        var pc: usize = 0;
        self.regs = self.orig;
        if (regA != INFINITY) {
            self.regs[0] = regA;
        }
        self.output.clearRetainingCapacity();
        self.fmt_len = 0;
        while (true) {
            const opcode = try Opcode.parse(self.program.items[pc]);
            pc += 1;
            const operand = self.program.items[pc];
            pc += 1;
            const dec = try self.decodeCombo(operand);
            switch (opcode) {
                .adv => self.regs[0] = self.regs[0] / (@as(u128, 1) << @intCast(dec)),
                .bxl => self.regs[1] = self.regs[1] ^ operand,
                .bst => self.regs[1] = dec % 8,
                .jnz => pc = if (self.regs[0] != 0) operand else pc,
                .bxc => self.regs[1] = self.regs[1] ^ self.regs[2],
                .out => try self.output.append(@intCast(dec % 8)),
                .bdv => self.regs[1] = self.regs[0] / (@as(u128, 1) << @intCast(dec)),
                .cdv => self.regs[2] = self.regs[0] / (@as(u128, 1) << @intCast(dec)),
            }
            if (pc >= self.program.items.len) break;
        }
    }

    fn decodeCombo(self: *Module, operand: u8) !u128 {
        return switch (operand) {
            0...3 => operand,
            4...6 => self.regs[operand - 4],
            else => error.InvalidOperand,
        };
    }
};

test "sample part 1 example 1" {
    const data =
        \\Register A: 729
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 0,1,5,4,3,0
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const output = try module.getProgramOutput();
    const expected = "4,6,3,5,6,3,5,2,1,0";
    try testing.expectEqualStrings(expected, output);
}

test "sample part 2" {
    const data =
        \\Register A: 2024
        \\Register B: 0
        \\Register C: 0
        \\
        \\Program: 0,3,5,4,3,0
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const rep = try module.findQuine();
    const expected = @as(u128, 117440);
    try testing.expectEqual(expected, rep);
}
