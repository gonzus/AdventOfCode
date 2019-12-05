const std = @import("std");
const assert = std.debug.assert;

pub const Computer = struct {
    rom: [4096]i32,
    ram: [4096]i32,
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

    pub fn init(str: []const u8) Computer {
        var self = Computer{
            .rom = undefined,
            .ram = undefined,
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
        return self.ram[pos];
    }

    pub fn set(self: *Computer, pos: usize, val: i32) void {
        self.ram[pos] = val;
    }

    pub fn append(self: *Computer, val: i32) void {
        // std.debug.warn("PC {} = {}\n", self.pos, val);
        self.rom[self.pos] = val;
        self.pos += 1;
    }

    pub fn run(self: *Computer, input: i32) i32 {
        var pc: usize = 0;
        var done = false;
        self.ram = self.rom;
        var last_printed: i32 = undefined;
        while (true) {
            var instr: u32 = @intCast(u32, self.ram[pc + 0]);
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
                    // std.debug.warn("HALT\n");
                    done = true;
                    break;
                },
                OP.ADD => {
                    const p1 = self.ram[pc + 1];
                    const v1: i32 = switch (m1) {
                        MODE.POSITION => self.ram[@intCast(usize, p1)],
                        MODE.IMMEDIATE => p1,
                    };
                    const p2 = self.ram[pc + 2];
                    const v2: i32 = switch (m2) {
                        MODE.POSITION => self.ram[@intCast(usize, p2)],
                        MODE.IMMEDIATE => p2,
                    };
                    const p3 = self.ram[pc + 3];
                    // std.debug.warn("ADD: {} = {} + {}\n", p3, v1, v2);
                    self.ram[@intCast(usize, p3)] = v1 + v2;
                    pc += 4;
                },
                OP.MUL => {
                    const p1 = self.ram[pc + 1];
                    const v1: i32 = switch (m1) {
                        MODE.POSITION => self.ram[@intCast(usize, p1)],
                        MODE.IMMEDIATE => p1,
                    };
                    const p2 = self.ram[pc + 2];
                    const v2: i32 = switch (m2) {
                        MODE.POSITION => self.ram[@intCast(usize, p2)],
                        MODE.IMMEDIATE => p2,
                    };
                    const p3 = self.ram[pc + 3];
                    // std.debug.warn("MUL: {} = {} * {}\n", p3, v1, v2);
                    self.ram[@intCast(usize, p3)] = v1 * v2;
                    pc += 4;
                },
                OP.RDSV => {
                    const p1 = self.ram[pc + 1];
                    const v1: i32 = switch (m1) {
                        MODE.POSITION => self.ram[@intCast(usize, p1)],
                        MODE.IMMEDIATE => p1,
                    };
                    // std.debug.warn("RDSV: {} = {}\n", p1, input);
                    self.ram[@intCast(usize, p1)] = input;
                    pc += 2;
                },
                OP.PRINT => {
                    const p1 = self.ram[pc + 1];
                    const v1: i32 = switch (m1) {
                        MODE.POSITION => self.ram[@intCast(usize, p1)],
                        MODE.IMMEDIATE => p1,
                    };
                    // std.debug.warn("PRINT: {}\n", v1);
                    last_printed = v1;
                    pc += 2;
                },
                OP.JIT => {
                    const p1 = self.ram[pc + 1];
                    const v1: i32 = switch (m1) {
                        MODE.POSITION => self.ram[@intCast(usize, p1)],
                        MODE.IMMEDIATE => p1,
                    };
                    const p2 = self.ram[pc + 2];
                    const v2: i32 = switch (m2) {
                        MODE.POSITION => self.ram[@intCast(usize, p2)],
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
                    const p1 = self.ram[pc + 1];
                    const v1: i32 = switch (m1) {
                        MODE.POSITION => self.ram[@intCast(usize, p1)],
                        MODE.IMMEDIATE => p1,
                    };
                    const p2 = self.ram[pc + 2];
                    const v2: i32 = switch (m2) {
                        MODE.POSITION => self.ram[@intCast(usize, p2)],
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
                    const p1 = self.ram[pc + 1];
                    const v1: i32 = switch (m1) {
                        MODE.POSITION => self.ram[@intCast(usize, p1)],
                        MODE.IMMEDIATE => p1,
                    };
                    const p2 = self.ram[pc + 2];
                    const v2: i32 = switch (m2) {
                        MODE.POSITION => self.ram[@intCast(usize, p2)],
                        MODE.IMMEDIATE => p2,
                    };
                    const p3 = self.ram[pc + 3];
                    // std.debug.warn("CLT: {} = {} LT {}\n", p3, v1, v2);
                    self.ram[@intCast(usize, p3)] = if (v1 < v2) 1 else 0;
                    pc += 4;
                },
                OP.CEQ => {
                    const p1 = self.ram[pc + 1];
                    const v1: i32 = switch (m1) {
                        MODE.POSITION => self.ram[@intCast(usize, p1)],
                        MODE.IMMEDIATE => p1,
                    };
                    const p2 = self.ram[pc + 2];
                    const v2: i32 = switch (m2) {
                        MODE.POSITION => self.ram[@intCast(usize, p2)],
                        MODE.IMMEDIATE => p2,
                    };
                    const p3 = self.ram[pc + 3];
                    // std.debug.warn("CEQ: {} = {} EQ {}\n", p3, v1, v2);
                    self.ram[@intCast(usize, p3)] = if (v1 == v2) 1 else 0;
                    pc += 4;
                },
            }
        }
        return last_printed;
    }
};

test "position mode - 1 if input equal to 8" {
    const data: []const u8 = "3,9,8,9,10,9,4,9,99,-1,8";
    var computer = Computer.init(data[0..]);
    assert(computer.run(7) == 0);
    assert(computer.run(8) == 1);
    assert(computer.run(9) == 0);
}

test "position mode - 1 if input less than 8" {
    const data: []const u8 = "3,9,7,9,10,9,4,9,99,-1,8";
    var computer = Computer.init(data[0..]);
    assert(computer.run(7) == 1);
    assert(computer.run(8) == 0);
    assert(computer.run(9) == 0);
}

test "immediate mode - 1 if input equal to 8" {
    const data: []const u8 = "3,3,1108,-1,8,3,4,3,99";
    var computer = Computer.init(data[0..]);
    assert(computer.run(7) == 0);
    assert(computer.run(8) == 1);
    assert(computer.run(9) == 0);
}

test "immediate mode - 1 if input less than 8" {
    const data: []const u8 = "3,3,1107,-1,8,3,4,3,99";
    var computer = Computer.init(data[0..]);
    assert(computer.run(7) == 1);
    assert(computer.run(8) == 0);
    assert(computer.run(9) == 0);
}

test "position mode - 0 if input is zero" {
    const data: []const u8 = "3,12,6,12,15,1,13,14,13,4,13,99,-1,0,1,9";
    var computer = Computer.init(data[0..]);
    assert(computer.run(0) == 0);
    assert(computer.run(1) == 1);
    assert(computer.run(2) == 1);
}

test "immediate mode - 0 if input is zero" {
    const data: []const u8 = "3,3,1105,-1,9,1101,0,0,12,4,12,99,1";
    var computer = Computer.init(data[0..]);
    assert(computer.run(0) == 0);
    assert(computer.run(1) == 1);
    assert(computer.run(2) == 1);
}

test "immediate mode - multitest for 8" {
    const data: []const u8 = "3,21,1008,21,8,20,1005,20,22,107,8,21,20,1006,20,31,1106,0,36,98,0,0,1002,21,125,20,4,20,1105,1,46,104,999,1105,1,46,1101,1000,1,20,4,20,1105,1,46,98,99";
    var computer = Computer.init(data[0..]);
    assert(computer.run(7) == 999);
    assert(computer.run(8) == 1000);
    assert(computer.run(9) == 1001);
}
