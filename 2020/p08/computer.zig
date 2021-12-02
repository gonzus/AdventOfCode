const std = @import("std");
const testing = std.testing;

pub const Computer = struct {
    accum: i32,
    instr: [1000]Instr,
    icount: usize,

    const Op = enum {
        None,
        ACC,
        JMP,
        NOP,
    };

    const Instr = struct {
        op: Op,
        arg: i32,
        count: usize,

        pub fn reset(self: *Instr, op: Op, arg: i32) void {
            self.op = op;
            self.arg = arg;
            self.count = 0;
        }
    };

    pub fn init() Computer {
        var self = Computer{
            .accum = 0,
            .icount = 0,
            .instr = undefined,
        };
        return self;
    }

    pub fn deinit(self: *Computer) void {
        _ = self;
    }

    pub fn add_instr(self: *Computer, line: []const u8) void {
        var it = std.mem.tokenize(u8, line, " ");

        const sop = it.next().?;
        var op = Op.None;
        if (std.mem.eql(u8, sop, "acc")) op = Op.ACC;
        if (std.mem.eql(u8, sop, "jmp")) op = Op.JMP;
        if (std.mem.eql(u8, sop, "nop")) op = Op.NOP;
        if (op == Op.None) @panic("OP");

        const sarg = it.next().?;
        const arg = std.fmt.parseInt(i32, sarg, 10) catch unreachable;

        self.instr[self.icount].reset(op, arg);
        // std.debug.warn("OP {} {}\n", .{ op, arg });
        self.icount += 1;
    }

    pub fn run_to_first_dupe(self: *Computer) bool {
        self.reset();
        var pc: isize = 0;
        while (true) {
            if (pc < 0) @panic("PC");
            if (pc >= self.icount) return true;
            const upc = @intCast(usize, pc);
            // std.debug.warn("RUN [{}]\n", .{self.instr[upc]});
            self.instr[upc].count += 1;
            if (self.instr[upc].count > 1) {
                break;
            }
            var incr: isize = 1;
            switch (self.instr[upc].op) {
                Op.NOP => {},
                Op.ACC => self.accum += self.instr[upc].arg,
                Op.JMP => incr = self.instr[upc].arg,
                else => @panic("RUN"),
            }
            pc += incr;
        }
        return false;
    }

    pub fn change_one_instr_until_success(self: *Computer) void {
        var pc: usize = 0;
        while (pc < self.icount) : (pc += 1) {
            const old = self.instr[pc].op;
            if (old != Op.NOP and old != Op.JMP) {
                continue;
            }
            const new = if (old == Op.NOP) Op.JMP else Op.NOP;
            self.instr[pc].op = new;
            const ok = self.run_to_first_dupe();
            self.instr[pc].op = old;
            if (ok) {
                return;
            }
        }
    }

    pub fn get_accumulator(self: *Computer) i32 {
        return self.accum;
    }

    fn reset(self: *Computer) void {
        self.accum = 0;
        var pc: usize = 0;
        while (pc < self.icount) : (pc += 1) {
            self.instr[pc].count = 0;
        }
    }
};

test "sample first dupe" {
    const data: []const u8 =
        \\nop +0
        \\acc +1
        \\jmp +4
        \\acc +3
        \\jmp -3
        \\acc -99
        \\acc +1
        \\jmp -4
        \\acc +6
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        computer.add_instr(line);
    }
    _ = computer.run_to_first_dupe();

    const accum = computer.get_accumulator();
    try testing.expect(accum == 5);
}

test "sample change one instr" {
    const data: []const u8 =
        \\nop +0
        \\acc +1
        \\jmp +4
        \\acc +3
        \\jmp -3
        \\acc -99
        \\acc +1
        \\jmp -4
        \\acc +6
    ;

    var computer = Computer.init();
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        computer.add_instr(line);
    }
    computer.change_one_instr_until_success();

    const accum = computer.get_accumulator();
    try testing.expect(accum == 8);
}
