const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Computer = struct {
    const INVALID_PC = std.math.maxInt(usize);
    const MAX_VALUE = 1000;
    const OUT_THRESHOLD = 100;

    const Reg = enum { a, b, c, d };
    const RegSize = std.meta.tags(Reg).len;

    const Operand = union(enum) {
        reg: Reg,
        num: isize,

        pub fn parse(op: []const u8) Operand {
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

        pub fn init(op0: Operand) Unary {
            return .{ .op0 = op0 };
        }

        pub fn parse(op0: []const u8) Unary {
            return Unary.init(Operand.parse(op0));
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
        cpy,
        inc,
        dec,
        jnz,
        tgl,
        out,

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
        tgl: Unary,
        out: Unary,

        pub fn toggle(self: Instr) Instr {
            return switch (self) {
                .inc => |t| Instr{ .dec = Unary.init(t.op0) },
                .jnz => |t| Instr{ .cpy = Binary.init(t.op0, t.op1) },
                .dec, .tgl, .out => |t| Instr{ .inc = Unary.init(t.op0) },
                .cpy => |t| Instr{ .jnz = Binary.init(t.op0, t.op1) },
            };
        }
    };

    reg: [RegSize]isize,
    instrs: std.ArrayList(Instr),
    pc: usize,
    halt: bool,
    out_last: isize,
    out_count: usize,

    pub fn init(allocator: Allocator) Computer {
        var self: Computer = undefined;
        self.instrs = std.ArrayList(Instr).init(allocator);
        self.reset();
        return self;
    }

    pub fn deinit(self: *Computer) void {
        self.instrs.deinit();
    }

    pub fn addLine(self: *Computer, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        const op = try Op.parse(it.next().?);
        const instr = switch (op) {
            .cpy => Instr{ .cpy = Binary.parse(it.next().?, it.next().?) },
            .inc => Instr{ .inc = Unary.parse(it.next().?) },
            .dec => Instr{ .dec = Unary.parse(it.next().?) },
            .jnz => Instr{ .jnz = Binary.parse(it.next().?, it.next().?) },
            .tgl => Instr{ .tgl = Unary.parse(it.next().?) },
            .out => Instr{ .out = Unary.parse(it.next().?) },
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
        for (0..RegSize) |r| {
            self.reg[r] = 0;
        }
        self.halt = false;
        self.out_last = 1;
        self.out_count = 0;
    }

    pub fn run(self: *Computer) !void {
        self.pc = 0;
        while (!self.halt and self.pc < self.instrs.items.len) {
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

    pub fn runUntilSignalIsGenerated(self: *Computer) !usize {
        for (0..MAX_VALUE) |value| {
            self.reset();
            self.setRegister(.a, @intCast(value));
            try self.run();
            if (self.out_count >= OUT_THRESHOLD) {
                return value;
            }
        }
        return 0;
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
            .jnz => |jnz| if (jnz.op0.getValue(self) != 0) {
                next = self.offsetPC(jnz.op1.getValue(self));
            },
            .tgl => |dec| switch (dec.op0) {
                .reg => |r| {
                    const pc = self.offsetPC(self.reg[@intFromEnum(r)]);
                    if (pc != INVALID_PC) {
                        self.instrs.items[pc] = self.instrs.items[pc].toggle();
                    }
                },
                .num => return error.InvalidReg,
            },
            .out => |out| {
                const wanted = 1 - self.out_last;
                const value = out.op0.getValue(self);
                self.out_last = value;
                if (wanted != value) {
                    self.out_count = 0;
                    self.halt = true;
                } else {
                    self.out_count += 1;
                    if (self.out_count >= OUT_THRESHOLD) {
                        self.halt = true;
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
