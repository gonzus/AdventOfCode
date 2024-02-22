const std = @import("std");
const testing = std.testing;
const SimpleQueue = @import("./util/queue.zig").SimpleQueue;

const Allocator = std.mem.Allocator;

pub const Cluster = struct {
    const Queue = SimpleQueue(isize);

    const INVALID_PC = std.math.maxInt(usize);
    const REGISTERS = 26;

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
        snd,
        set,
        add,
        mul,
        mod,
        rcv,
        jgz,

        pub fn parse(str: []const u8) !Op {
            for (Ops) |op| {
                if (std.mem.eql(u8, str, @tagName(op))) return op;
            }
            return error.InvalidOp;
        }
    };
    const Ops = std.meta.tags(Op);

    const Instr = union(Op) {
        snd: Unary,
        set: Binary,
        add: Binary,
        mul: Binary,
        mod: Binary,
        rcv: Unary,
        jgz: Binary,

        pub fn initUnary(op: Op, u: Unary) !Instr {
            return switch (op) {
                .snd => Instr{ .snd = u },
                .rcv => Instr{ .rcv = u },
                else => error.InvalidInstr,
            };
        }

        pub fn initBinary(op: Op, b: Binary) !Instr {
            return switch (op) {
                .set => Instr{ .set = b },
                .add => Instr{ .add = b },
                .mul => Instr{ .mul = b },
                .mod => Instr{ .mod = b },
                .jgz => Instr{ .jgz = b },
                else => error.InvalidInstr,
            };
        }

        pub fn format(
            v: Instr,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = switch (v) {
                .snd => |i| try writer.print("snd {}", .{i.op0}),
                .set => |i| try writer.print("set {},{}", .{ i.op0, i.op1 }),
                .add => |i| try writer.print("add {},{}", .{ i.op0, i.op1 }),
                .mul => |i| try writer.print("mul {},{}", .{ i.op0, i.op1 }),
                .mod => |i| try writer.print("mod {},{}", .{ i.op0, i.op1 }),
                .rcv => |i| try writer.print("rcv {}", .{i.op0}),
                .jgz => |i| try writer.print("jgz {},{}", .{ i.op0, i.op1 }),
            };
        }
    };

    const Computer = struct {
        id: usize,
        messaging: bool,
        instrs: std.ArrayList(Instr),
        regs: [REGISTERS]isize,
        pc: usize,
        halted: bool,
        blocked: bool,
        last_freq: isize,
        queue: Queue,
        send_count: isize,
        pending: ?isize,

        pub fn init(allocator: Allocator, id: usize, messaging: bool) Computer {
            return .{
                .id = id,
                .messaging = messaging,
                .instrs = std.ArrayList(Instr).init(allocator),
                .regs = undefined,
                .pc = 0,
                .halted = false,
                .blocked = false,
                .last_freq = 0,
                .queue = Queue.init(allocator),
                .send_count = 0,
                .pending = null,
            };
        }

        pub fn deinit(self: *Computer) void {
            self.queue.deinit();
            self.instrs.deinit();
        }

        pub fn show(self: Computer) void {
            std.debug.print("Computer id {} with {} instructions\n", .{ self.id, self.instrs.items.len });
            for (self.instrs.items) |instr| {
                std.debug.print("{}\n", .{instr});
            }
        }

        pub fn reset(self: *Computer) void {
            for (&self.regs) |*r| {
                r.* = 0;
            }
            self.setRegister('p', @intCast(self.id));
            self.halted = false;
            self.blocked = false;
            self.last_freq = 0;
            self.queue.clear();
            self.send_count = 0;
            self.pc = 0;
        }

        pub fn run(self: *Computer) !void {
            while (!self.finished()) {
                try self.step();
            }
        }

        pub fn step(self: *Computer) !void {
            const instr = self.instrs.items[self.pc];
            self.pc = try self.execInstr(instr);
        }

        pub fn finished(self: Computer) bool {
            if (self.halted) return true;
            if (self.pc >= self.instrs.items.len) {
                return true;
            }
            return false;
        }

        pub fn getRegister(self: *Computer, reg: u8) isize {
            return self.regs[reg - 'a'];
        }

        pub fn setRegister(self: *Computer, reg: u8, value: isize) void {
            self.regs[reg - 'a'] = value;
        }

        fn execInstr(self: *Computer, instr: Instr) !usize {
            var next = self.pc + 1;
            switch (instr) {
                .snd => |i| {
                    if (self.messaging) {
                        self.pending = i.op0.getValue(self);
                    } else {
                        self.last_freq = i.op0.getValue(self);
                    }
                },
                .set => |i| switch (i.op0) {
                    .reg => |r| self.setRegister(r, i.op1.getValue(self)),
                    .num => return error.InvalidReg,
                },
                .add => |i| switch (i.op0) {
                    .reg => |r| self.setRegister(r, self.getRegister(r) + i.op1.getValue(self)),
                    .num => return error.InvalidReg,
                },
                .mul => |i| switch (i.op0) {
                    .reg => |r| self.setRegister(r, self.getRegister(r) * i.op1.getValue(self)),
                    .num => return error.InvalidReg,
                },
                .mod => |i| switch (i.op0) {
                    .reg => |r| self.setRegister(r, @mod(self.getRegister(r), i.op1.getValue(self))),
                    .num => return error.InvalidReg,
                },
                .rcv => |i| {
                    if (self.messaging) {
                        if (self.queue.empty()) {
                            self.blocked = true;
                            next = self.pc;
                        } else {
                            switch (i.op0) {
                                .reg => |r| self.setRegister(r, try self.queue.dequeue()),
                                .num => return error.InvalidReg,
                            }
                        }
                    } else {
                        if (i.op0.getValue(self) != 0) {
                            self.halted = true;
                            next = self.pc;
                        }
                    }
                },
                .jgz => |i| {
                    if (i.op0.getValue(self) > 0) {
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

    messaging: bool,
    computers: [2]Computer,

    pub fn init(allocator: Allocator, messaging: bool) Cluster {
        var self: Cluster = undefined;
        self.messaging = messaging;
        for (&self.computers, 0..) |*c, p| {
            c.* = Computer.init(allocator, p, messaging);
            c.*.reset();
        }
        return self;
    }

    pub fn deinit(self: *Cluster) void {
        for (&self.computers) |*c| {
            c.*.deinit();
        }
    }

    pub fn addLine(self: *Cluster, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        const op = try Op.parse(it.next().?);
        const instr = switch (op) {
            .snd, .rcv => |o| try Instr.initUnary(o, Unary.parse(it.next().?)),
            .jgz, .set, .add, .mul, .mod => |o| try Instr.initBinary(o, Binary.parse(it.next().?, it.next().?)),
        };
        for (&self.computers) |*c| {
            try c.*.instrs.append(instr);
        }
    }

    pub fn show(self: Cluster) void {
        std.debug.print("Cluster with {} computers\n", .{self.computers.len});
        for (&self.computers) |c| {
            c.show();
        }
    }

    pub fn reset(self: *Cluster) void {
        for (&self.computers) |*c| {
            c.*.reset();
        }
    }

    pub fn run(self: *Cluster) !void {
        if (!self.messaging) {
            try self.computers[0].run();
            return;
        }
        while (true) {
            var halted: usize = 0;
            var blocked: usize = 0;
            for (&self.computers) |c| {
                if (c.halted) {
                    halted += 1;
                }
                if (c.blocked) {
                    blocked += 1;
                }
            }
            if (halted == 2 or blocked == 2) break;

            for (&self.computers, 0..) |*c, p| {
                try c.step();
                if (c.pending) |v| {
                    c.send_count += 1;
                    try self.computers[1 - p].queue.enqueue(v);
                }
                c.pending = null;
            }
        }
    }

    pub fn getLastFrequencyOnRcv(self: *Cluster, program: usize) !isize {
        self.reset();
        try self.run();
        return self.computers[program].last_freq;
    }

    pub fn getSendCountForProgram(self: *Cluster, program: usize) !isize {
        self.reset();
        try self.run();
        return self.computers[program].send_count;
    }
};

test "sample part 1" {
    const data =
        \\set a 1
        \\add a 2
        \\mul a a
        \\mod a 5
        \\snd a
        \\set a 0
        \\rcv a
        \\jgz a -1
        \\set a 1
        \\jgz a -2
    ;

    var cluster = Cluster.init(std.testing.allocator, false);
    defer cluster.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    const frequency = try cluster.getLastFrequencyOnRcv(0);
    const expected = @as(isize, 4);
    try testing.expectEqual(expected, frequency);
}

test "sample part 2" {
    const data =
        \\snd 1
        \\snd 2
        \\snd p
        \\rcv a
        \\rcv b
        \\rcv c
        \\rcv d
    ;

    var cluster = Cluster.init(std.testing.allocator, true);
    defer cluster.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    const count = try cluster.getSendCountForProgram(1);
    const expected = @as(isize, 3);
    try testing.expectEqual(expected, count);
}
