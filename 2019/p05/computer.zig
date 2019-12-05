const std = @import("std");

pub const Computer = struct {
    mem: [4096]i32,
    pos: usize,

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

    pub fn init(str: []u8) Computer {
        var self = Computer{
            .mem = undefined,
            .pos = 0,
        };
        var cur: i32 = 0;
        var neg = false;
        var j: usize = 0;
        var l: usize = 0;
        while (true) {
            if (j < str.len and str[j] == '-') {
                neg = true;
            } else if (j >= str.len or str[j] < '0' or str[j] > '9') {
                self.append(if (neg) -cur else cur);
                cur = 0;
                neg = false;
                l = 0;
                if (j >= str.len) {
                    break;
                }
            } else {
                cur = cur * 10 + @intCast(i32, str[j] - '0');
                l += 1;
            }
            j += 1;
        }
        return self;
    }

    pub fn get(self: Computer, pos: usize) i32 {
        return self.mem[pos];
    }

    pub fn set(self: *Computer, pos: usize, val: i32) void {
        self.mem[pos] = val;
    }

    pub fn append(self: *Computer, val: i32) void {
        // std.debug.warn("PC {} = {}\n", self.pos, val);
        self.mem[self.pos] = val;
        self.pos += 1;
    }

    pub fn run(self: *Computer, input: i32) void {
        var pc: usize = 0;
        var done = false;
        while (true) {
            var instr: u32 = @intCast(u32, self.mem[pc + 0]);
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
                    std.debug.warn("HALT\n");
                    done = true;
                    break;
                },
                OP.ADD => {
                    const p1 = self.mem[pc + 1];
                    const v1: i32 = switch (m1) {
                        MODE.POSITION => self.mem[@intCast(usize, p1)],
                        MODE.IMMEDIATE => p1,
                    };
                    const p2 = self.mem[pc + 2];
                    const v2: i32 = switch (m2) {
                        MODE.POSITION => self.mem[@intCast(usize, p2)],
                        MODE.IMMEDIATE => p2,
                    };
                    const p3 = self.mem[pc + 3];
                    // std.debug.warn("ADD: {} = {} + {}\n", p3, v1, v2);
                    self.mem[@intCast(usize, p3)] = v1 + v2;
                    pc += 4;
                },
                OP.MUL => {
                    const p1 = self.mem[pc + 1];
                    const v1: i32 = switch (m1) {
                        MODE.POSITION => self.mem[@intCast(usize, p1)],
                        MODE.IMMEDIATE => p1,
                    };
                    const p2 = self.mem[pc + 2];
                    const v2: i32 = switch (m2) {
                        MODE.POSITION => self.mem[@intCast(usize, p2)],
                        MODE.IMMEDIATE => p2,
                    };
                    const p3 = self.mem[pc + 3];
                    // std.debug.warn("MUL: {} = {} * {}\n", p3, v1, v2);
                    self.mem[@intCast(usize, p3)] = v1 * v2;
                    pc += 4;
                },
                OP.RDSV => {
                    const p1 = self.mem[pc + 1];
                    const v1: i32 = switch (m1) {
                        MODE.POSITION => self.mem[@intCast(usize, p1)],
                        MODE.IMMEDIATE => p1,
                    };
                    std.debug.warn("RDSV: {} = {}\n", p1, input);
                    self.mem[@intCast(usize, p1)] = input;
                    pc += 2;
                },
                OP.PRINT => {
                    const p1 = self.mem[pc + 1];
                    const v1: i32 = switch (m1) {
                        MODE.POSITION => self.mem[@intCast(usize, p1)],
                        MODE.IMMEDIATE => p1,
                    };
                    std.debug.warn("PRINT: {}\n", v1);
                    pc += 2;
                },
                OP.JIT => {
                    const p1 = self.mem[pc + 1];
                    const v1: i32 = switch (m1) {
                        MODE.POSITION => self.mem[@intCast(usize, p1)],
                        MODE.IMMEDIATE => p1,
                    };
                    const p2 = self.mem[pc + 2];
                    const v2: i32 = switch (m2) {
                        MODE.POSITION => self.mem[@intCast(usize, p2)],
                        MODE.IMMEDIATE => p2,
                    };
                    // std.debug.warn("JIT: {} {}\n", v1, v2);
                    if (v1 == 0) {
                        pc += 3;
                    } else {
                        pc = @intCast(usize, v2);
                    }
                },
                OP.JIF => {
                    const p1 = self.mem[pc + 1];
                    const v1: i32 = switch (m1) {
                        MODE.POSITION => self.mem[@intCast(usize, p1)],
                        MODE.IMMEDIATE => p1,
                    };
                    const p2 = self.mem[pc + 2];
                    const v2: i32 = switch (m2) {
                        MODE.POSITION => self.mem[@intCast(usize, p2)],
                        MODE.IMMEDIATE => p2,
                    };
                    // std.debug.warn("JIF: {} {}\n", v1, v2);
                    if (v1 == 0) {
                        pc = @intCast(usize, v2);
                    } else {
                        pc += 3;
                    }
                },
                OP.CLT => {
                    const p1 = self.mem[pc + 1];
                    const v1: i32 = switch (m1) {
                        MODE.POSITION => self.mem[@intCast(usize, p1)],
                        MODE.IMMEDIATE => p1,
                    };
                    const p2 = self.mem[pc + 2];
                    const v2: i32 = switch (m2) {
                        MODE.POSITION => self.mem[@intCast(usize, p2)],
                        MODE.IMMEDIATE => p2,
                    };
                    const p3 = self.mem[pc + 3];
                    // std.debug.warn("CLT: {} = {} LT {}\n", p3, v1, v2);
                    self.mem[@intCast(usize, p3)] = if (v1 < v2) 1 else 0;
                    pc += 4;
                },
                OP.CEQ => {
                    const p1 = self.mem[pc + 1];
                    const v1: i32 = switch (m1) {
                        MODE.POSITION => self.mem[@intCast(usize, p1)],
                        MODE.IMMEDIATE => p1,
                    };
                    const p2 = self.mem[pc + 2];
                    const v2: i32 = switch (m2) {
                        MODE.POSITION => self.mem[@intCast(usize, p2)],
                        MODE.IMMEDIATE => p2,
                    };
                    const p3 = self.mem[pc + 3];
                    // std.debug.warn("CEQ: {} = {} EQ {}\n", p3, v1, v2);
                    self.mem[@intCast(usize, p3)] = if (v1 == v2) 1 else 0;
                    pc += 4;
                },
            }
        }
    }
};
