const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Computer = struct {
    const INFINITY = std.math.maxInt(usize);
    const REGS = 4;
    const MIN_OPCODE_COUNT = 3;

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
    };
    const OPS = std.meta.tags(Op);

    const Instr = struct {
        op: Op,
        num: usize,
        args: [3]usize,

        pub fn init() Instr {
            return .{
                .op = undefined,
                .num = undefined,
                .args = undefined,
            };
        }

        pub fn parse(str: []const u8) !Instr {
            var self = Instr.init();
            var it = std.mem.tokenizeScalar(u8, str, ' ');
            self.num = try std.fmt.parseUnsigned(usize, it.next().?, 10);
            for (0..3) |a| {
                self.args[a] = try std.fmt.parseUnsigned(usize, it.next().?, 10);
            }
            return self;
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

        pub fn parse(str: []const u8) !Regs {
            var self = Regs.init();
            var it = std.mem.tokenizeAny(u8, str, " :[,]");
            _ = it.next();
            var pos: usize = 0;
            while (it.next()) |chunk| : (pos += 1) {
                self.data[pos] = try std.fmt.parseUnsigned(usize, chunk, 10);
            }
            return self;
        }

        pub fn equal(self: Regs, other: Regs) bool {
            for (&self.data, &other.data) |s, o| {
                if (s != o) return false;
            }
            return true;
        }
    };

    before: Regs,
    run: Instr,
    after: Regs,
    nls: usize,
    regs: Regs,
    instrs: std.ArrayList(Instr),
    count: usize,
    masks: [OPS.len]usize,
    mapping: [OPS.len]usize,

    pub fn init(allocator: Allocator) !Computer {
        return .{
            .before = Regs.init(),
            .run = Instr.init(),
            .after = Regs.init(),
            .nls = 0,
            .regs = Regs.init(),
            .instrs = std.ArrayList(Instr).init(allocator),
            .count = 0,
            .masks = [_]usize{0} ** OPS.len,
            .mapping = [_]usize{INFINITY} ** OPS.len,
        };
    }

    pub fn deinit(self: *Computer) void {
        self.instrs.deinit();
    }

    pub fn addLine(self: *Computer, line: []const u8) !void {
        if (line.len == 0) {
            self.nls += 1;
            return;
        }
        if (self.nls >= 3) {
            const instr = try Instr.parse(line);
            try self.instrs.append(instr);
            return;
        }
        self.nls = 0;
        var it = std.mem.tokenizeAny(u8, line, " :[,]");
        const first = it.next().?;
        if (std.mem.eql(u8, first, "Before")) {
            self.before = try Regs.parse(line);
            return;
        }
        if (std.mem.eql(u8, first, "After")) {
            self.after = try Regs.parse(line);
            self.findPossibleOps();
            return;
        }
        self.run = try Instr.parse(line);
    }

    pub fn getSampleCount(self: Computer) usize {
        return self.count;
    }

    pub fn runCode(self: *Computer) !usize {
        try self.findFullOpMap();

        self.regs = Regs.init();
        for (self.instrs.items) |*instr| {
            instr.op = @enumFromInt(self.mapping[instr.num]);
            self.runOp(instr.*);
        }
        return self.reg(0);
    }

    fn reg(self: Computer, pos: usize) usize {
        return self.regs.data[pos];
    }

    fn setReg(self: *Computer, pos: usize, value: usize) void {
        self.regs.data[pos] = value;
    }

    fn findPossibleOps(self: *Computer) void {
        var count: usize = 0;
        var instr = self.run;
        var p: usize = 0;
        while (p < OPS.len) : (p += 1) {
            instr.op = @enumFromInt(p);
            self.regs = self.before;
            self.runOp(instr);
            if (!self.regs.equal(self.after)) continue;
            count += 1;
            self.masks[p] |= @as(usize, 1) << @intCast(self.run.num);
        }
        if (count < MIN_OPCODE_COUNT) return;
        self.count += 1;
    }

    fn findFullOpMap(self: *Computer) !void {
        var found: usize = 0;
        while (found < OPS.len) {
            var changed: usize = 0;
            for (0..OPS.len) |op| {
                const bits = @popCount(self.masks[op]);
                if (bits != 1) continue;
                const pos = @ctz(self.masks[op]);
                if (self.mapping[pos] != INFINITY) {
                    if (self.mapping[pos] != op) return error.MultipleMapping;
                    continue;
                }
                self.mapping[pos] = op;
                changed += 1;
                for (0..OPS.len) |other| {
                    if (other == op) continue;
                    self.masks[other] &= ~(@as(usize, 1) << @intCast(pos));
                }
            }
            if (changed == 0) {
                return error.ImpossibleMapping;
            }
            found += changed;
        }
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
        \\Before: [3, 2, 1, 1]
        \\9 2 1 2
        \\After:  [3, 2, 2, 1]
    ;

    var computer = try Computer.init(testing.allocator);
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.addLine(line);
    }

    const score = computer.getSampleCount();
    const expected = 1;
    try testing.expectEqual(expected, score);
}
