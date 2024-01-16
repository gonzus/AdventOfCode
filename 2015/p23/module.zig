const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Computer = struct {
    const Op = enum {
        hlf,
        tpl,
        inc,
        jmp,
        jie,
        jio,

        pub fn parse(str: []const u8) !Op {
            for (Ops) |op| {
                if (std.mem.eql(u8, str, @tagName(op))) return op;
            }
            return error.InvalidOp;
        }
    };
    const Ops = std.meta.tags(Op);

    const Register = enum {
        a,
        b,

        pub fn parse(str: []const u8) !Register {
            for (Registers) |reg| {
                if (std.mem.eql(u8, str, @tagName(reg))) return reg;
            }
            return error.InvalidRegister;
        }
    };
    const Registers = std.meta.tags(Register);

    const Instr = struct {
        op: Op,
        register: Register,
        offset: isize,

        pub fn init() Instr {
            return Instr{ .op = undefined, .register = undefined, .offset = 0 };
        }
    };

    allocator: Allocator,
    instrs: std.ArrayList(Instr),
    registers: [Registers.len]usize,
    pc: usize,

    pub fn init(allocator: Allocator) Computer {
        return Computer{
            .allocator = allocator,
            .instrs = std.ArrayList(Instr).init(allocator),
            .registers = [_]usize{0} ** Registers.len,
            .pc = 0,
        };
    }

    pub fn deinit(self: *Computer) void {
        self.instrs.deinit();
    }

    pub fn addLine(self: *Computer, line: []const u8) !void {
        var instr = Instr.init();
        var pos: usize = 0;
        var it = std.mem.tokenizeAny(u8, line, " ,");
        while (it.next()) |chunk| : (pos += 1) {
            switch (pos) {
                0 => instr.op = try Op.parse(chunk),
                1 => switch (instr.op) {
                    .jmp => instr.offset = try parseOffset(chunk),
                    else => instr.register = try Register.parse(chunk),
                },
                2 => instr.offset = try parseOffset(chunk),
                else => return error.InvalidData,
            }
        }
        try self.instrs.append(instr);
    }

    pub fn show(self: Computer) void {
        std.debug.print("Computer with {} instructions:\n", .{self.instrs.items.len});
        for (self.instrs.items) |i| {
            std.debug.print("{} {} {}\n", .{ i.op, i.register, i.offset });
        }
    }

    pub fn getRegister(self: *Computer, register: Register) usize {
        const r = @intFromEnum(register);
        return self.registers[r];
    }

    pub fn setRegister(self: *Computer, register: Register, value: usize) void {
        const r = @intFromEnum(register);
        self.registers[r] = value;
    }

    pub fn run(self: *Computer) !void {
        self.pc = 0;
        while (self.pc < self.instrs.items.len) {
            self.pc = try self.runCurrent();
        }
    }

    fn runCurrent(self: *Computer) !usize {
        const instr = self.instrs.items[self.pc];
        const reg = @intFromEnum(instr.register);
        const off = instr.offset;
        var next: usize = self.pc + 1;
        switch (instr.op) {
            .hlf => self.registers[reg] /= 2,
            .tpl => self.registers[reg] *= 3,
            .inc => self.registers[reg] += 1,
            .jmp => next = try self.jump(off),
            .jie => if (self.registers[reg] % 2 == 0) {
                next = try self.jump(off);
            },
            .jio => if (self.registers[reg] == 1) {
                next = try self.jump(off);
            },
        }
        return next;
    }

    fn parseOffset(str: []const u8) !isize {
        const sign: isize = if (str[0] == '+') 1 else -1;
        return try std.fmt.parseInt(isize, str[1..], 10) * sign;
    }

    fn jump(self: *Computer, offset: isize) !usize {
        var pc: isize = @intCast(self.pc);
        pc += offset;
        if (pc < 0) return error.InvalidPC;
        return @intCast(pc);
    }
};

test "sample part 1" {
    const data =
        \\inc a
        \\jio a, +2
        \\tpl a
        \\inc a
    ;

    var computer = Computer.init(std.testing.allocator);
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.addLine(line);
    }
    // computer.show();

    try computer.run();
    const register = computer.getRegister(.a);
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, register);
}
