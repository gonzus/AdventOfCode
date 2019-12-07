const std = @import("std");
const assert = std.debug.assert;

pub const Computer = struct {
    rom: [4096]i32,
    ram: [4096]i32,
    pc: usize,
    pos: usize,
    inputs: [4096]i32,
    piw: usize,
    pir: usize,
    outputs: [4096]i32,
    pow: usize,
    por: usize,
    reentrant: bool,
    halted: bool,

    const OP = enum(u32) {
        ADD = 1,
        MUL = 2,
        RDSV = 3,
        PRINT = 4,
        JIT = 5,
        JIF = 6,
        CLT = 7,
        CEQ = 8,
        HALT = 99,
    };

    const MODE = enum(u32) {
        POSITION = 0,
        IMMEDIATE = 1,
    };

    pub fn init(str: []const u8) Computer {
        var self = Computer{
            .rom = undefined,
            .ram = undefined,
            .pc = 0,
            .pos = 0,
            .inputs = undefined,
            .piw = 0,
            .pir = 0,
            .outputs = undefined,
            .pow = 0,
            .por = 0,
            .reentrant = false,
            .halted = false,
        };
        var it = std.mem.separate(str, ",");
        while (it.next()) |what| {
            const instr = std.fmt.parseInt(i32, what, 10) catch unreachable;
            self.rom[self.pos] = instr;
            self.pos += 1;
        }
        self.resetRAM();
        return self;
    }

    pub fn get(self: Computer, pos: usize) i32 {
        return self.ram[pos];
    }

    pub fn set(self: *Computer, pos: usize, val: i32) void {
        self.ram[pos] = val;
    }

    pub fn resetRAM(self: *Computer) void {
        std.debug.warn("RESET\n");
        self.ram = self.rom;
        self.halted = false;
        self.pc = 0;
    }

    pub fn enqueueInput(self: *Computer, input: i32) void {
        // std.debug.warn("ENQUEUE {} in pos {}\n", input, self.piw);
        self.inputs[self.piw] = input;
        self.piw += 1;
    }

    pub fn setReentrant(self: *Computer) void {
        self.reentrant = true;
    }

    pub fn getOutput(self: *Computer) ?i32 {
        if (self.por >= self.pow) {
            return null;
        }
        const result = self.outputs[self.por];
        self.por += 1;
        if (self.por == self.pow) {
            self.pow = 0;
            self.por = 0;
        }
        return result;
    }

    pub fn run(self: *Computer) ?i32 {
        if (!self.reentrant) self.resetRAM();

        while (!self.halted) {
            var instr: u32 = @intCast(u32, self.ram[self.pc + 0]);
            // std.debug.warn("instr: {}\n", instr);
            const op = @intToEnum(OP, instr % 100);
            instr /= 100;
            const m1 = @intToEnum(MODE, instr % 10);
            instr /= 10;
            const m2 = @intToEnum(MODE, instr % 10);
            instr /= 10;
            const m3 = @intToEnum(MODE, instr % 10);
            instr /= 10;
            switch (op) {
                OP.HALT => {
                    std.debug.warn("{} | HALT\n", self.pc);
                    self.halted = true;
                    break;
                },
                OP.ADD => {
                    const v1 = self.decode(1, m1);
                    const v2 = self.decode(2, m2);
                    const p3 = self.ram[self.pc + 3];
                    std.debug.warn("{} | ADD: {} = {} + {}\n", self.pc, p3, v1, v2);
                    self.ram[@intCast(usize, p3)] = v1 + v2;
                    self.pc += 4;
                },
                OP.MUL => {
                    const v1 = self.decode(1, m1);
                    const v2 = self.decode(2, m2);
                    const p3 = self.ram[self.pc + 3];
                    std.debug.warn("{} | MUL: {} = {} * {}\n", self.pc, p3, v1, v2);
                    self.ram[@intCast(usize, p3)] = v1 * v2;
                    self.pc += 4;
                },
                OP.RDSV => {
                    if (self.pir >= self.piw) {
                        std.debug.warn("{} | RDSV: PAUSED {} {}\n", self.pc, self.pir, self.piw);
                        break;
                    }
                    const p1 = self.ram[self.pc + 1];
                    std.debug.warn("{} | RDSV: {} = {}\n", self.pc, p1, self.inputs[self.pir]);
                    self.ram[@intCast(usize, p1)] = self.inputs[self.pir];
                    self.pir += 1;
                    if (self.pir == self.piw) {
                        self.pir = 0;
                        self.piw = 0;
                    }
                    self.pc += 2;
                },
                OP.PRINT => {
                    const v1 = self.decode(1, m1);
                    std.debug.warn("{} | PRINT: {}\n", self.pc, v1);
                    self.outputs[self.pow] = v1;
                    self.pow += 1;
                    self.pc += 2;
                },
                OP.JIT => {
                    const v1 = self.decode(1, m1);
                    const v2 = self.decode(2, m2);
                    std.debug.warn("{} | JIT: {} {}\n", self.pc, v1, v2);
                    if (v1 == 0) {
                        self.pc += 3;
                    } else {
                        self.pc = @intCast(usize, v2);
                    }
                },
                OP.JIF => {
                    const v1 = self.decode(1, m1);
                    const v2 = self.decode(2, m2);
                    std.debug.warn("{} | JIF: {} {}\n", self.pc, v1, v2);
                    if (v1 == 0) {
                        self.pc = @intCast(usize, v2);
                    } else {
                        self.pc += 3;
                    }
                },
                OP.CLT => {
                    const v1 = self.decode(1, m1);
                    const v2 = self.decode(2, m2);
                    const p3 = self.ram[self.pc + 3];
                    std.debug.warn("{} | CLT: {} = {} LT {}\n", self.pc, p3, v1, v2);
                    self.ram[@intCast(usize, p3)] = if (v1 < v2) 1 else 0;
                    self.pc += 4;
                },
                OP.CEQ => {
                    const v1 = self.decode(1, m1);
                    const v2 = self.decode(2, m2);
                    const p3 = self.ram[self.pc + 3];
                    std.debug.warn("{} | CEQ: {} = {} EQ {}\n", self.pc, p3, v1, v2);
                    self.ram[@intCast(usize, p3)] = if (v1 == v2) 1 else 0;
                    self.pc += 4;
                },
            }
        }
        return self.getOutput();
    }

    fn decode(self: Computer, pos: usize, mode: MODE) i32 {
        const p = self.ram[self.pc + pos];
        const v: i32 = switch (mode) {
            MODE.POSITION => self.ram[@intCast(usize, p)],
            MODE.IMMEDIATE => p,
        };
        return v;
    }

    pub fn get_thruster_signal(self: *Computer, phase: [5]u8) i32 {
        // std.debug.warn("PHASES: {}\n", phases);
        var previous: i32 = 0;
        var j: usize = 0;
        while (j < phase.len) {
            self.enqueueInput(phase[j]);
            self.enqueueInput(previous);
            const output = self.run();
            std.debug.warn("NODE {}: {} => {}\n", j, previous, output.?);
            previous = output.?;
            j += 1;
        }
        // std.debug.warn("SIGNAL {}\n", inputs[1]);
        return previous;
    }

    pub fn optimize_thruster_signal(self: *Computer) i32 {
        var phase = [5]u8{ 0, 1, 2, 3, 4 };
        var mp = [5]u8{ 0, 0, 0, 0, 0 };
        var mt: i32 = std.math.minInt(i32);
        self.ots(&phase, phase.len, &mp, &mt);
        return mt;
    }

    fn ots(self: *Computer, phase: *[5]u8, len: usize, mp: *[5]u8, mt: *i32) void {
        if (len == 1) {
            const t = self.get_thruster_signal(phase.*);
            if (mt.* < t) {
                mt.* = t;
                mp[0] = phase[0];
                mp[1] = phase[1];
                mp[2] = phase[2];
                mp[3] = phase[3];
                mp[4] = phase[4];
            }
            return;
        }

        var j: usize = 0;
        while (j < phase.len) : (j += 1) {
            const m = len - 1;
            var t: u8 = 0;

            t = phase[j];
            phase[j] = phase[m];
            phase[m] = t;

            self.ots(phase, m, mp, mt);

            t = phase[j];
            phase[j] = phase[m];
            phase[m] = t;
        }
    }
};

test "thruster signals, short program" {
    std.debug.warn("\n");
    const code: []const u8 = "3,15,3,16,1002,16,10,16,1,16,15,15,4,15,99,0,0";
    const phases = [5]u8{ 4, 3, 2, 1, 0 };
    var computer = Computer.init(code[0..]);
    assert(computer.get_thruster_signal(phases) == 43210);
}

test "thruster signals, medium program" {
    std.debug.warn("\n");
    const code: []const u8 = "3,23,3,24,1002,24,10,24,1002,23,-1,23,101,5,23,23,1,24,23,23,4,23,99,0,0";
    const phases = [5]u8{ 0, 1, 2, 3, 4 };
    var computer = Computer.init(code[0..]);
    assert(computer.get_thruster_signal(phases) == 54321);
}

test "thruster signals, long program" {
    std.debug.warn("\n");
    const code: []const u8 = "3,31,3,32,1002,32,10,32,1001,31,-2,31,1007,31,0,33,1002,33,7,33,1,33,31,31,1,32,31,31,4,31,99,0,0,0";
    const phases = [5]u8{ 1, 0, 4, 3, 2 };
    var computer = Computer.init(code[0..]);
    assert(computer.get_thruster_signal(phases) == 65210);
}

test "optimize thruster signals, short program" {
    std.debug.warn("\n");
    const code: []const u8 = "3,15,3,16,1002,16,10,16,1,16,15,15,4,15,99,0,0";
    var computer = Computer.init(code[0..]);
    assert(computer.optimize_thruster_signal() == 43210);
}
