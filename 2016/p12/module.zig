const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Computer = struct {
    const Reg = enum { a, b, c, d };
    const RegSize = std.meta.tags(Reg).len;

    const Operand = union(enum) {
        reg: Reg,
        num: isize,

        pub fn init(op: []const u8) Operand {
            const num = std.fmt.parseInt(isize, op, 10) catch {
                const reg: Reg = @enumFromInt(op[0] - 'a');
                return Operand{ .reg = reg };
            };
            return Operand{ .num = num };
        }

        pub fn getValue(self: Operand, computer: *Computer) isize {
            return switch (self) {
                .reg => |r| computer.*.reg[@intFromEnum(r)],
                .num => |n| n,
            };
        }
    };

    const Unary = struct {
        op0: Operand,

        pub fn init(op0: []const u8) Unary {
            return Unary{ .op0 = Operand.init(op0) };
        }
    };

    const Binary = struct {
        op0: Operand,
        op1: Operand,

        pub fn init(op0: []const u8, op1: []const u8) Binary {
            return Binary{ .op0 = Operand.init(op0), .op1 = Operand.init(op1) };
        }
    };

    const Op = enum {
        cpy,
        inc,
        dec,
        jnz,

        pub fn parse(str: []const u8) !Op {
            for (Ops) |o| {
                if (std.mem.eql(u8, str, @tagName(o))) return o;
            }
            return error.InvalidOp;
        }
    };
    const Ops = std.meta.tags(Op);

    const Instr = union(Op) {
        cpy: Binary,
        inc: Unary,
        dec: Unary,
        jnz: Binary,
    };

    reg: [RegSize]isize,
    instrs: std.ArrayList(Instr),
    pc: usize,

    pub fn init(allocator: Allocator) Computer {
        return Computer{
            .reg = [_]isize{0} ** RegSize,
            .instrs = std.ArrayList(Instr).init(allocator),
            .pc = 0,
        };
    }

    pub fn deinit(self: *Computer) void {
        self.instrs.deinit();
    }

    pub fn addLine(self: *Computer, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        const op = try Op.parse(it.next().?);
        const instr = switch (op) {
            .cpy => Instr{ .cpy = Binary.init(it.next().?, it.next().?) },
            .inc => Instr{ .inc = Unary.init(it.next().?) },
            .dec => Instr{ .dec = Unary.init(it.next().?) },
            .jnz => Instr{ .jnz = Binary.init(it.next().?, it.next().?) },
        };
        try self.instrs.append(instr);
    }

    pub fn show(self: Computer) void {
        std.debug.print("Computer with {} instructions\n", .{self.instrs.items.len});
        for (self.instrs.items) |instr| {
            std.debug.print("{}\n", .{instr});
        }
    }

    pub fn run(self: *Computer) !void {
        self.pc = 0;
        while (self.pc < self.instrs.items.len) {
            const instr = self.instrs.items[self.pc];
            self.pc = try self.execInstr(instr);
        }
    }

    pub fn getRegister(self: *Computer, reg: Reg) isize {
        return self.reg[@intFromEnum(reg)];
    }

    pub fn setRegister(self: *Computer, reg: Reg, value: isize) void {
        self.reg[@intFromEnum(reg)] = value;
    }

    fn execInstr(self: *Computer, instr: Instr) !usize {
        var next = self.pc + 1;
        switch (instr) {
            .cpy => |cpy| switch (cpy.op1) {
                .reg => |r| self.reg[@intFromEnum(r)] = cpy.op0.getValue(self),
                .num => return error.InvalidReg,
            },
            .inc => |inc| switch (inc.op0) {
                .reg => |r| self.reg[@intFromEnum(r)] += 1,
                .num => return error.InvalidReg,
            },
            .dec => |dec| switch (dec.op0) {
                .reg => |r| self.reg[@intFromEnum(r)] -= 1,
                .num => return error.InvalidReg,
            },
            .jnz => |jnz| {
                if (jnz.op0.getValue(self) != 0) {
                    const pc: isize = @intCast(self.pc);
                    next = @intCast(pc + jnz.op1.getValue(self));
                }
            },
        }
        return next;
    }
};

test "sample part 1" {
    const data =
        \\cpy 41 a
        \\inc a
        \\inc a
        \\dec a
        \\jnz a 2
        \\dec a
    ;

    var computer = Computer.init(std.testing.allocator);
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.addLine(line);
    }
    // computer.show();

    try computer.run();
    const value = computer.getRegister(.a);
    const expected = @as(isize, 42);
    try testing.expectEqual(expected, value);
}
