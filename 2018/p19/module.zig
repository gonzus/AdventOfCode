const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Computer = struct {
    const REGS = 6;
    const ARGS = 3;

    const Op = enum {
        addr,
        addi,
        mulr,
        muli,
        banr,
        bani,
        borr,
        bori,
        setr,
        seti,
        gtir,
        gtri,
        gtrr,
        eqir,
        eqri,
        eqrr,

        pub fn parse(str: []const u8) !Op {
            for (Ops) |o| {
                if (std.mem.eql(u8, @tagName(o), str)) return o;
            }
            return error.InvalidOp;
        }

        pub fn format(
            self: Op,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print("{s}", .{@tagName(self)});
        }
    };
    const Ops = std.meta.tags(Op);

    const Instr = struct {
        op: Op,
        args: [ARGS]usize,

        pub fn init() Instr {
            return .{
                .op = undefined,
                .args = undefined,
            };
        }

        pub fn parse(str: []const u8) !Instr {
            var self = Instr.init();
            var it = std.mem.tokenizeScalar(u8, str, ' ');
            var pos: usize = 0;
            self.op = try Op.parse(it.next().?);
            while (it.next()) |chunk| : (pos += 1) {
                self.args[pos] = try std.fmt.parseUnsigned(usize, chunk, 10);
            }
            return self;
        }

        pub fn format(
            self: Instr,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print("{}", .{self.op});
            for (0..ARGS) |pos| {
                try writer.print(" {}", .{self.args[pos]});
            }
        }

        pub fn arg(self: Instr, pos: usize) usize {
            return self.args[pos];
        }
    };

    const Regs = struct {
        data: [REGS]usize,

        pub fn init() Regs {
            return .{
                .data = [_]usize{0} ** REGS,
            };
        }
    };

    ip: usize,
    regs: Regs,
    instrs: std.ArrayList(Instr),

    pub fn init(allocator: Allocator) !Computer {
        return .{
            .ip = 0,
            .regs = Regs.init(),
            .instrs = std.ArrayList(Instr).init(allocator),
        };
    }

    pub fn deinit(self: *Computer) void {
        self.instrs.deinit();
    }

    pub fn addLine(self: *Computer, line: []const u8) !void {
        if (line[0] == '#') {
            var it = std.mem.tokenizeAny(u8, line, " #");
            const pragma = it.next().?;
            if (std.mem.eql(u8, pragma, "ip")) {
                self.ip = try std.fmt.parseUnsigned(usize, it.next().?, 10);
                return;
            }
        }
        try self.instrs.append(try Instr.parse(line));
    }

    pub fn show(self: Computer) void {
        std.debug.print("Computer with {} instructions, ip={}\n", .{ self.instrs.items.len, self.ip });
        for (self.instrs.items) |instr| {
            std.debug.print("{}\n", .{instr});
        }
    }

    pub fn runCodeWithRegZero(self: *Computer, value: usize) usize {
        if (value == 0 or value == 1) {
            // reverse-engineered code
            const a = self.instrs.items[21].args[1];
            const b = self.instrs.items[23].args[1];
            var n: usize = 836 + 22 * a + b;
            if (value == 1) {
                n += 10550400;
            }
            const root: usize = @intCast(std.math.sqrt(n));
            var sum: usize = 0;
            for (1..root + 1) |d| {
                if (n % d != 0) continue;
                sum += d + n / d;
            }
            if (root * root == n) sum -= root;
            return sum;
        }

        // run the code for real
        self.regs = Regs.init();
        self.setReg(0, value);
        return self.runCode();
    }

    fn runCode(self: *Computer) usize {
        var pc = self.reg(self.ip);
        while (true) {
            if (pc >= self.instrs.items.len) break;
            self.setReg(self.ip, pc);
            self.runOp(self.instrs.items[pc]);
            pc = self.reg(self.ip);
            pc += 1;
        }
        return self.reg(0);
    }

    fn reg(self: Computer, pos: usize) usize {
        return self.regs.data[pos];
    }

    fn setReg(self: *Computer, pos: usize, value: usize) void {
        self.regs.data[pos] = value;
    }

    fn runOp(self: *Computer, instr: Instr) void {
        switch (instr.op) {
            .addr => self.runAdd(self.reg(instr.arg(0)), self.reg(instr.arg(1)), instr.arg(2)),
            .addi => self.runAdd(self.reg(instr.arg(0)), instr.arg(1), instr.arg(2)),
            .mulr => self.runMul(self.reg(instr.arg(0)), self.reg(instr.arg(1)), instr.arg(2)),
            .muli => self.runMul(self.reg(instr.arg(0)), instr.arg(1), instr.arg(2)),
            .banr => self.runAnd(self.reg(instr.arg(0)), self.reg(instr.arg(1)), instr.arg(2)),
            .bani => self.runAnd(self.reg(instr.arg(0)), instr.arg(1), instr.arg(2)),
            .borr => self.runOr(self.reg(instr.arg(0)), self.reg(instr.arg(1)), instr.arg(2)),
            .bori => self.runOr(self.reg(instr.arg(0)), instr.arg(1), instr.arg(2)),
            .setr => self.runSet(self.reg(instr.arg(0)), instr.arg(2)),
            .seti => self.runSet(instr.arg(0), instr.arg(2)),
            .gtir => self.runGT(instr.arg(0), self.reg(instr.arg(1)), instr.arg(2)),
            .gtri => self.runGT(self.reg(instr.arg(0)), instr.arg(1), instr.arg(2)),
            .gtrr => self.runGT(self.reg(instr.arg(0)), self.reg(instr.arg(1)), instr.arg(2)),
            .eqir => self.runEQ(instr.arg(0), self.reg(instr.arg(1)), instr.arg(2)),
            .eqri => self.runEQ(self.reg(instr.arg(0)), instr.arg(1), instr.arg(2)),
            .eqrr => self.runEQ(self.reg(instr.arg(0)), self.reg(instr.arg(1)), instr.arg(2)),
        }
    }

    fn runAdd(self: *Computer, A: usize, B: usize, C: usize) void {
        self.setReg(C, A + B);
    }

    fn runMul(self: *Computer, A: usize, B: usize, C: usize) void {
        self.setReg(C, A * B);
    }

    fn runAnd(self: *Computer, A: usize, B: usize, C: usize) void {
        self.setReg(C, A & B);
    }

    fn runOr(self: *Computer, A: usize, B: usize, C: usize) void {
        self.setReg(C, A | B);
    }

    fn runSet(self: *Computer, A: usize, C: usize) void {
        self.setReg(C, A);
    }

    fn runGT(self: *Computer, A: usize, B: usize, C: usize) void {
        self.setReg(C, if (A > B) 1 else 0);
    }

    fn runEQ(self: *Computer, A: usize, B: usize, C: usize) void {
        self.setReg(C, if (A == B) 1 else 0);
    }
};

test "sample part 1" {
    const data =
        \\#ip 0
        \\seti 5 0 1
        \\seti 6 0 2
        \\addi 0 1 0
        \\addr 1 2 3
        \\setr 1 0 0
        \\seti 8 0 4
        \\seti 9 0 5
    ;

    var computer = try Computer.init(testing.allocator);
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.addLine(line);
    }

    const value = computer.runCode();
    const expected = 6;
    try testing.expectEqual(expected, value);
}
