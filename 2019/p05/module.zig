const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Computer = struct {
    const Op = enum(u8) {
        add = 1,
        mul = 2,
        rdsv = 3,
        print = 4,
        jit = 5,
        jif = 6,
        clt = 7,
        ceq = 8,
        halt = 99,

        pub fn decode(num: usize) !Op {
            for (Ops) |op| {
                if (@intFromEnum(op) == num) return op;
            }
            return error.InvalidOp;
        }
    };
    const Ops = std.meta.tags(Op);

    const Mode = enum(u8) {
        position = 0,
        immediate = 1,

        pub fn decode(num: usize) !Mode {
            for (Modes) |mode| {
                if (@intFromEnum(mode) == num) return mode;
            }
            return error.InvalidMode;
        }
    };
    const Modes = std.meta.tags(Mode);

    code: std.ArrayList(isize),
    data: std.ArrayList(isize),
    pc: usize,
    input: isize,
    last_printed: isize,

    pub fn init(allocator: Allocator) Computer {
        return .{
            .code = std.ArrayList(isize).init(allocator),
            .data = std.ArrayList(isize).init(allocator),
            .pc = 0,
            .input = 0,
            .last_printed = 0,
        };
    }

    pub fn deinit(self: *Computer) void {
        self.data.deinit();
        self.code.deinit();
    }

    pub fn addLine(self: *Computer, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ',');
        while (it.next()) |chunk| {
            try self.code.append(try std.fmt.parseInt(isize, chunk, 10));
        }
    }

    fn reset(self: *Computer) !void {
        self.data.clearRetainingCapacity();
        for (self.code.items) |c| {
            try self.data.append(c);
        }
        self.pc = 0;
        self.input = 0;
        self.last_printed = 0;
    }

    pub fn runWithInput(self: *Computer, input: isize) !isize {
        try self.reset();
        self.input = input;
        try self.run();
        return self.last_printed;
    }

    fn run(self: *Computer) !void {
        while (true) {
            var instr = self.getCurrentInstruction();
            const op = try Op.decode(instr % 100);
            instr /= 100;
            const m1 = try Mode.decode(instr % 10);
            instr /= 10;
            const m2 = try Mode.decode(instr % 10);
            instr /= 10;
            switch (op) {
                .halt => break,
                .add => {
                    const v1 = self.decodeValue(1, m1);
                    const v2 = self.decodeValue(2, m2);
                    const p3 = self.getOffset(3);
                    self.setData(p3, v1 + v2);
                    self.incrPC(4);
                },
                .mul => {
                    const v1 = self.decodeValue(1, m1);
                    const v2 = self.decodeValue(2, m2);
                    const p3 = self.getOffset(3);
                    self.setData(p3, v1 * v2);
                    self.incrPC(4);
                },
                .rdsv => {
                    const p1 = self.getOffset(1);
                    self.setData(p1, self.input);
                    self.incrPC(2);
                },
                .print => {
                    const v1 = self.decodeValue(1, m1);
                    self.last_printed = v1;
                    self.incrPC(2);
                },
                .jit => {
                    const v1 = self.decodeValue(1, m1);
                    const v2 = self.decodeValue(2, m2);
                    if (v1 == 0) {
                        self.incrPC(3);
                    } else {
                        self.setPC(v2);
                    }
                },
                .jif => {
                    const v1 = self.decodeValue(1, m1);
                    const v2 = self.decodeValue(2, m2);
                    if (v1 == 0) {
                        self.setPC(v2);
                    } else {
                        self.incrPC(3);
                    }
                },
                .clt => {
                    const v1 = self.decodeValue(1, m1);
                    const v2 = self.decodeValue(2, m2);
                    const p3 = self.getOffset(3);
                    self.setData(p3, if (v1 < v2) 1 else 0);
                    self.incrPC(4);
                },
                .ceq => {
                    const v1 = self.decodeValue(1, m1);
                    const v2 = self.decodeValue(2, m2);
                    const p3 = self.getOffset(3);
                    self.setData(p3, if (v1 == v2) 1 else 0);
                    self.incrPC(4);
                },
            }
        }
    }

    fn getCurrentInstruction(self: Computer) usize {
        return @intCast(self.data.items[self.pc + 0]);
    }

    fn getOffset(self: Computer, offset: usize) isize {
        const data = self.data.items;
        return data[self.pc + offset];
    }

    fn getData(self: Computer, pos: isize) isize {
        const data = self.data.items;
        const addr: usize = @intCast(pos);
        return data[addr];
    }

    fn setData(self: *Computer, pos: isize, val: isize) void {
        const data = self.data.items;
        const addr: usize = @intCast(pos);
        data[addr] = val;
    }

    fn setPC(self: *Computer, pc: isize) void {
        self.pc = @intCast(pc);
    }

    fn incrPC(self: *Computer, delta: usize) void {
        self.pc += delta;
    }

    fn decodeValue(self: Computer, offset: usize, mode: Mode) isize {
        const pos = self.getOffset(offset);
        return switch (mode) {
            .position => self.getData(pos),
            .immediate => pos,
        };
    }
};
