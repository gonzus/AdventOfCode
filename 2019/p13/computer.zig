const std = @import("std");
const assert = std.debug.assert;

pub const IntBuf = struct {
    data: []i64,
    pw: usize,
    pr: usize,

    pub fn init(size: usize) IntBuf {
        var self = IntBuf{
            .data = undefined,
            .pw = 0,
            .pr = 0,
        };
        const allocator = std.heap.direct_allocator;
        self.data = allocator.alloc(i64, size) catch @panic("FUCK\n");
        std.mem.set(i64, self.data[0..], 0);
        return self;
    }

    pub fn deinit(self: *IntBuf) void {
        const allocator = std.heap.direct_allocator;
        allocator.free(self.data);
    }

    pub fn empty(self: IntBuf) bool {
        return (self.pr >= self.pw);
    }

    pub fn read(self: IntBuf, pos: usize) ?i64 {
        return self.data[pos];
    }

    pub fn write(self: *IntBuf, pos: usize, value: i64) void {
        self.data[pos] = value;
    }

    pub fn get(self: *IntBuf) ?i64 {
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

    pub fn put(self: *IntBuf, value: i64) void {
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
    debug: bool,
    base: i64,

    const OP = enum(u32) {
        ADD = 1,
        MUL = 2,
        RDSV = 3,
        PRINT = 4,
        JIT = 5,
        JIF = 6,
        CLT = 7,
        CEQ = 8,
        RBO = 9,
        HALT = 99,
    };

    const MODE = enum(u32) {
        POSITION = 0,
        IMMEDIATE = 1,
        RELATIVE = 2,
    };

    pub fn init(reentrant: bool) Computer {
        const mem_size = 10 * 1024;
        const io_size = 10 * 1024;
        var self = Computer{
            .rom = IntBuf.init(mem_size),
            .ram = IntBuf.init(mem_size),
            .pc = 0,
            .inputs = IntBuf.init(io_size),
            .outputs = IntBuf.init(io_size),
            .reentrant = reentrant,
            .halted = false,
            .debug = false,
            .base = 2,
        };
        self.clear();
        return self;
    }

    pub fn deinit(self: *Computer) void {
        self.outputs.deinit();
        self.inputs.deinit();
        self.ram.deinit();
        self.rom.deinit();
    }

    pub fn parse(self: *Computer, str: []const u8, hack: bool) void {
        var it = std.mem.separate(str, ",");
        while (it.next()) |what| {
            const instr = std.fmt.parseInt(i64, what, 10) catch unreachable;
            self.rom.put(instr);
        }
        if (hack) {
            const value: i64 = 2;
            std.debug.warn("HACKING ROM: pos 0, {} => {}\n", self.rom.data[0], value);
            self.rom.data[0] = value;
        }
        self.clear();
    }

    pub fn get(self: Computer, pos: usize) i64 {
        return self.ram.read(pos);
    }

    pub fn set(self: *Computer, pos: usize, val: i64) void {
        self.ram.write(pos, val);
    }

    pub fn clear(self: *Computer) void {
        if (self.debug) std.debug.warn("RESET\n");
        self.ram = self.rom;
        self.halted = false;
        self.pc = 0;
        self.inputs.clear();
        self.outputs.clear();
    }

    pub fn enqueueInput(self: *Computer, input: i64) void {
        if (self.debug) std.debug.warn("ENQUEUE {}\n", input);
        self.inputs.put(input);
    }

    pub fn setReentrant(self: *Computer) void {
        self.reentrant = true;
    }

    pub fn getOutput(self: *Computer) ?i64 {
        if (self.outputs.empty()) {
            return null;
        }
        const result = self.outputs.get().?;
        return result;
    }

    pub fn run(self: *Computer) void {
        if (!self.reentrant) self.clear();

        while (!self.halted) {
            var instr: u32 = @intCast(u32, self.ram.read(self.pc + 0).?);
            // if (self.debug) std.debug.warn("instr @ {}: {}\n", self.pc, instr);
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
                    if (self.debug) std.debug.warn("{} | HALT\n", self.pc);
                    self.halted = true;
                    break;
                },
                OP.ADD => {
                    const v1 = self.read_decoded(1, m1);
                    const v2 = self.read_decoded(2, m2);
                    if (self.debug) std.debug.warn("{} | ADD: {} + {}\n", self.pc, v1, v2);
                    self.write_decoded(3, m3, v1 + v2);
                    self.pc += 4;
                },
                OP.MUL => {
                    const v1 = self.read_decoded(1, m1);
                    const v2 = self.read_decoded(2, m2);
                    if (self.debug) std.debug.warn("{} | MUL: {} * {}\n", self.pc, v1, v2);
                    self.write_decoded(3, m3, v1 * v2);
                    self.pc += 4;
                },
                OP.RDSV => {
                    if (self.inputs.empty()) {
                        if (self.debug) std.debug.warn("{} | RDSV: PAUSED\n", self.pc);
                        break;
                    }
                    const value = self.inputs.get().?;
                    if (self.debug) std.debug.warn("{} | RDSV: {}\n", self.pc, value);
                    self.write_decoded(1, m1, value);
                    self.pc += 2;
                },
                OP.PRINT => {
                    const v1 = self.read_decoded(1, m1);
                    if (self.debug) std.debug.warn("{} | PRINT: {}\n", self.pc, v1);
                    self.outputs.put(v1);
                    self.pc += 2;
                },
                OP.JIT => {
                    const v1 = self.read_decoded(1, m1);
                    const v2 = self.read_decoded(2, m2);
                    if (self.debug) std.debug.warn("{} | JIT: {} {}\n", self.pc, v1, v2);
                    if (v1 == 0) {
                        self.pc += 3;
                    } else {
                        self.pc = @intCast(usize, v2);
                    }
                },
                OP.JIF => {
                    const v1 = self.read_decoded(1, m1);
                    const v2 = self.read_decoded(2, m2);
                    if (self.debug) std.debug.warn("{} | JIF: {} {}\n", self.pc, v1, v2);
                    if (v1 == 0) {
                        self.pc = @intCast(usize, v2);
                    } else {
                        self.pc += 3;
                    }
                },
                OP.CLT => {
                    const v1 = self.read_decoded(1, m1);
                    const v2 = self.read_decoded(2, m2);
                    if (self.debug) std.debug.warn("{} | CLT: {} LT {}\n", self.pc, v1, v2);

                    // tried doing this way, got an error:
                    //
                    // const value: i32 = if (v1 < v2) 1 else 0;
                    // error: cannot store runtime value in type 'comptime_int'
                    //
                    var value: i64 = 0;
                    if (v1 < v2) value = 1;
                    self.write_decoded(3, m3, value);
                    self.pc += 4;
                },
                OP.CEQ => {
                    const v1 = self.read_decoded(1, m1);
                    const v2 = self.read_decoded(2, m2);
                    var value: i64 = 0;
                    if (v1 == v2) value = 1;
                    if (self.debug) std.debug.warn("{} | CEQ: {} EQ {} ? {}\n", self.pc, v1, v2, value);
                    self.write_decoded(3, m3, value);
                    self.pc += 4;
                },
                OP.RBO => {
                    const v1 = self.read_decoded(1, m1);
                    const base = self.base;
                    self.base += v1;
                    if (self.debug) std.debug.warn("{} | RBO: {} + {} => {}\n", self.pc, base, v1, self.base);
                    self.pc += 2;
                },
            }
        }
    }

    fn read_decoded(self: Computer, pos: usize, mode: MODE) i64 {
        const p = self.ram.read(self.pc + pos).?;
        var v: i64 = 0;
        switch (mode) {
            MODE.POSITION => {
                v = self.ram.read(@intCast(usize, p)).?;
                // if (self.debug) std.debug.warn("READ_DECODED POSITION {} => {}\n", p, v);
            },
            MODE.IMMEDIATE => {
                v = p;
                // if (self.debug) std.debug.warn("READ_DECODED IMMEDIATE => {}\n", v);
            },
            MODE.RELATIVE => {
                const q = p + self.base;
                v = self.ram.read(@intCast(usize, q)).?;
                // if (self.debug) std.debug.warn("READ_DECODED RELATIVE {} + {} = {} => {}\n", p, self.base, q, v);
            },
        }
        return v;
    }

    fn write_decoded(self: *Computer, pos: usize, mode: MODE, value: i64) void {
        const p = self.ram.read(self.pc + pos).?;
        // if (self.debug) std.debug.warn("WRITE_DECODED {} {}: {} => {}\n", self.pc + pos, mode, p, value);
        switch (mode) {
            MODE.POSITION => self.ram.write(@intCast(usize, p), value),
            MODE.IMMEDIATE => unreachable,
            MODE.RELATIVE => self.ram.write(@intCast(usize, p + self.base), value),
        }
    }
};
