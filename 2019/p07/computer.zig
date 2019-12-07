const std = @import("std");
const assert = std.debug.assert;

pub const IntBuf = struct {
    data: [4096]i32,
    pw: usize,
    pr: usize,

    pub fn init() IntBuf {
        var self = IntBuf{
            .data = undefined,
            .pw = 0,
            .pr = 0,
        };
        return self;
    }

    pub fn empty(self: IntBuf) bool {
        return (self.pr >= self.pw);
    }

    pub fn read(self: IntBuf, pos: usize) ?i32 {
        if (pos >= self.pw) {
            return null;
        }
        return self.data[pos];
    }

    pub fn write(self: *IntBuf, pos: usize, value: i32) void {
        self.data[pos] = value;
    }

    pub fn get(self: *IntBuf) ?i32 {
        if (self.empty()) {
            return null;
        }
        const value = self.data[self.pr];
        self.pr += 1;
        if (self.empty()) {
            self.clear();
        }
        return value;
    }

    pub fn put(self: *IntBuf, value: i32) void {
        self.data[self.pw] = value;
        self.pw += 1;
    }

    pub fn clear(self: *IntBuf) void {
        self.pr = 0;
        self.pw = 0;
    }
};

pub const Computer = struct {
    rom: IntBuf,
    ram: IntBuf,
    pc: usize,
    inputs: IntBuf,
    outputs: IntBuf,
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
            .inputs = undefined,
            .outputs = undefined,
            .reentrant = false,
            .halted = false,
        };
        var it = std.mem.separate(str, ",");
        while (it.next()) |what| {
            const instr = std.fmt.parseInt(i32, what, 10) catch unreachable;
            self.rom.put(instr);
        }
        self.clear();
        return self;
    }

    pub fn deinit(self: *Computer) void {}

    pub fn get(self: Computer, pos: usize) i32 {
        return self.ram.read(pos);
    }

    pub fn set(self: *Computer, pos: usize, val: i32) void {
        self.ram.write(pos, val);
    }

    pub fn clear(self: *Computer) void {
        // std.debug.warn("RESET\n");
        self.ram = self.rom;
        self.halted = false;
        self.pc = 0;
        self.inputs.clear();
        self.outputs.clear();
    }

    pub fn enqueueInput(self: *Computer, input: i32) void {
        // std.debug.warn("ENQUEUE {}\n", input);
        self.inputs.put(input);
    }

    pub fn setReentrant(self: *Computer) void {
        self.reentrant = true;
    }

    pub fn getOutput(self: *Computer) ?i32 {
        if (self.outputs.empty()) {
            return null;
        }
        const result = self.outputs.get().?;
        return result;
    }

    pub fn run(self: *Computer) ?i32 {
        if (!self.reentrant) self.clear();

        while (!self.halted) {
            var instr: u32 = @intCast(u32, self.ram.read(self.pc + 0).?);
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
                    // std.debug.warn("{} | HALT\n", self.pc);
                    self.halted = true;
                    break;
                },
                OP.ADD => {
                    const v1 = self.decode(1, m1);
                    const v2 = self.decode(2, m2);
                    const p3 = self.ram.read(self.pc + 3).?;
                    // std.debug.warn("{} | ADD: {} = {} + {}\n", self.pc, p3, v1, v2);
                    self.ram.write(@intCast(usize, p3), v1 + v2);
                    self.pc += 4;
                },
                OP.MUL => {
                    const v1 = self.decode(1, m1);
                    const v2 = self.decode(2, m2);
                    const p3 = self.ram.read(self.pc + 3).?;
                    // std.debug.warn("{} | MUL: {} = {} * {}\n", self.pc, p3, v1, v2);
                    self.ram.write(@intCast(usize, p3), v1 * v2);
                    self.pc += 4;
                },
                OP.RDSV => {
                    if (self.inputs.empty()) {
                        // std.debug.warn("{} | RDSV: PAUSED\n", self.pc);
                        break;
                    }
                    const p1 = self.ram.read(self.pc + 1).?;
                    // std.debug.warn("{} | RDSV: {} = {}\n", self.pc, p1, self.inputs.get());
                    self.ram.write(@intCast(usize, p1), self.inputs.get().?);
                    self.pc += 2;
                },
                OP.PRINT => {
                    const v1 = self.decode(1, m1);
                    // std.debug.warn("{} | PRINT: {}\n", self.pc, v1);
                    self.outputs.put(v1);
                    self.pc += 2;
                },
                OP.JIT => {
                    const v1 = self.decode(1, m1);
                    const v2 = self.decode(2, m2);
                    // std.debug.warn("{} | JIT: {} {}\n", self.pc, v1, v2);
                    if (v1 == 0) {
                        self.pc += 3;
                    } else {
                        self.pc = @intCast(usize, v2);
                    }
                },
                OP.JIF => {
                    const v1 = self.decode(1, m1);
                    const v2 = self.decode(2, m2);
                    // std.debug.warn("{} | JIF: {} {}\n", self.pc, v1, v2);
                    if (v1 == 0) {
                        self.pc = @intCast(usize, v2);
                    } else {
                        self.pc += 3;
                    }
                },
                OP.CLT => {
                    const v1 = self.decode(1, m1);
                    const v2 = self.decode(2, m2);
                    const p3 = self.ram.read(self.pc + 3).?;
                    // std.debug.warn("{} | CLT: {} = {} LT {}\n", self.pc, p3, v1, v2);

                    // tried doing this way, got an error:
                    //
                    // const value: i32 = if (v1 < v2) 1 else 0;
                    // error: cannot store runtime value in type 'comptime_int'
                    //
                    var value: i32 = 0;
                    if (v1 < v2) value = 1;
                    self.ram.write(@intCast(usize, p3), value);
                    self.pc += 4;
                },
                OP.CEQ => {
                    const v1 = self.decode(1, m1);
                    const v2 = self.decode(2, m2);
                    const p3 = self.ram.read(self.pc + 3).?;
                    // std.debug.warn("{} | CEQ: {} = {} EQ {}\n", self.pc, p3, v1, v2);
                    var value: i32 = 0;
                    if (v1 == v2) value = 1;
                    self.ram.write(@intCast(usize, p3), value);
                    self.pc += 4;
                },
            }
        }
        return self.getOutput();
    }

    fn decode(self: Computer, pos: usize, mode: MODE) i32 {
        const p = self.ram.read(self.pc + pos).?;
        const v: i32 = switch (mode) {
            MODE.POSITION => self.ram.read(@intCast(usize, p)).?,
            MODE.IMMEDIATE => p,
        };
        return v;
    }
};
