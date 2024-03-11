const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Computer = struct {
    const INVALID_PC = std.math.maxInt(usize);
    const REGISTERS = 8;

    const Operand = union(enum) {
        reg: u8,
        num: isize,

        pub fn parse(op: []const u8) Operand {
            const num = std.fmt.parseInt(isize, op, 10) catch {
                const reg: u8 = op[0];
                return Operand{ .reg = reg };
            };
            return Operand{ .num = num };
        }

        pub fn getValue(self: Operand, computer: *Computer) isize {
            return switch (self) {
                .reg => |r| computer.getRegister(r),
                .num => |n| n,
            };
        }

        pub fn format(
            v: Operand,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = switch (v) {
                .reg => |r| try writer.print("R[{c}]", .{r}),
                .num => |n| try writer.print("N[{d}]", .{n}),
            };
        }
    };

    const Binary = struct {
        op0: Operand,
        op1: Operand,

        pub fn init(op0: Operand, op1: Operand) Binary {
            return .{ .op0 = op0, .op1 = op1 };
        }

        pub fn parse(op0: []const u8, op1: []const u8) Binary {
            return Binary.init(Operand.parse(op0), Operand.parse(op1));
        }
    };

    const Op = enum {
        set,
        sub,
        mul,
        jnz,

        pub fn parse(str: []const u8) !Op {
            for (Ops) |op| {
                if (std.mem.eql(u8, str, @tagName(op))) return op;
            }
            return error.InvalidOp;
        }
    };
    const Ops = std.meta.tags(Op);

    const Instr = union(Op) {
        set: Binary,
        sub: Binary,
        mul: Binary,
        jnz: Binary,

        pub fn initBinary(op: Op, b: Binary) !Instr {
            return switch (op) {
                .set => Instr{ .set = b },
                .sub => Instr{ .sub = b },
                .mul => Instr{ .mul = b },
                .jnz => Instr{ .jnz = b },
            };
        }

        pub fn format(
            v: Instr,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = switch (v) {
                .set => |i| try writer.print("set {},{}", .{ i.op0, i.op1 }),
                .sub => |i| try writer.print("sub {},{}", .{ i.op0, i.op1 }),
                .mul => |i| try writer.print("mul {},{}", .{ i.op0, i.op1 }),
                .jnz => |i| try writer.print("jnz {},{}", .{ i.op0, i.op1 }),
            };
        }
    };

    instrs: std.ArrayList(Instr),
    regs: [REGISTERS]isize,
    pc: usize,

    pub fn init(allocator: Allocator) Computer {
        return .{
            .instrs = std.ArrayList(Instr).init(allocator),
            .regs = undefined,
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
            .set, .sub, .mul, .jnz => |o| try Instr.initBinary(o, Binary.parse(it.next().?, it.next().?)),
        };
        try self.instrs.append(instr);
    }

    pub fn show(self: Computer) void {
        std.debug.print("Computer with {} instructions\n", .{self.instrs.items.len});
        for (self.instrs.items) |instr| {
            std.debug.print("{}\n", .{instr});
        }
    }

    pub fn reset(self: *Computer) void {
        for (&self.regs) |*r| {
            r.* = 0;
        }
        self.pc = 0;
    }

    pub fn getRegister(self: *Computer, reg: u8) isize {
        return self.regs[reg - 'a'];
    }

    pub fn setRegister(self: *Computer, reg: u8, value: isize) void {
        self.regs[reg - 'a'] = value;
    }

    pub fn runAndCountMul(self: *Computer) !usize {
        self.reset();
        try self.warmUp();
        var prod: isize = 1;
        prod *= self.getRegister('b') - self.getRegister('e');
        prod *= self.getRegister('b') - self.getRegister('d');
        return @intCast(prod);
    }

    pub fn runAndCountNonPrimes(self: *Computer) !usize {
        self.reset();
        self.setRegister('a', 1);
        try self.warmUp();
        var count: usize = 0;
        const top = self.getRegister('c');
        var num = self.getRegister('b');
        while (num <= top) : (num += 17) {
            if (Math.isPrime(@intCast(num))) continue;
            count += 1;
        }
        return count;
    }

    fn warmUp(self: *Computer) !void {
        while (self.pc < 11) {
            const instr = self.instrs.items[self.pc];
            self.pc = try self.execInstr(instr);
        }
    }

    fn execInstr(self: *Computer, instr: Instr) !usize {
        var next = self.pc + 1;
        switch (instr) {
            .set => |i| switch (i.op0) {
                .reg => |r| self.setRegister(r, i.op1.getValue(self)),
                .num => return error.InvalidReg,
            },
            .sub => |i| switch (i.op0) {
                .reg => |r| self.setRegister(r, self.getRegister(r) - i.op1.getValue(self)),
                .num => return error.InvalidReg,
            },
            .mul => |i| switch (i.op0) {
                .reg => |r| self.setRegister(r, self.getRegister(r) * i.op1.getValue(self)),
                .num => return error.InvalidReg,
            },
            .jnz => |i| {
                if (i.op0.getValue(self) != 0) {
                    const pc = self.offsetPC(i.op1.getValue(self));
                    if (pc != INVALID_PC) {
                        next = pc;
                    }
                }
            },
        }
        return next;
    }

    fn offsetPC(self: Computer, offset: isize) usize {
        var pc: isize = @intCast(self.pc);
        pc += offset;
        if (pc < 0) return INVALID_PC;
        if (pc >= self.instrs.items.len) return INVALID_PC;
        return @intCast(pc);
    }
};
