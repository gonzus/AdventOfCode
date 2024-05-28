const std = @import("std");
const testing = std.testing;
const DoubleEndedQueue = @import("./util/queue.zig").DoubleEndedQueue;

const Allocator = std.mem.Allocator;

pub const Computer = struct {
    const Queue = DoubleEndedQueue(isize);
    const INFINITY = std.math.maxInt(isize);

    const Op = enum(u8) {
        add = 1,
        mul = 2,
        rdsv = 3,
        print = 4,
        jit = 5,
        jif = 6,
        clt = 7,
        ceq = 8,
        rbo = 9,
        halt = 99,

        pub fn decode(num: usize) !Op {
            for (Ops) |op| {
                if (@intFromEnum(op) == num) return op;
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

    const Mode = enum(u8) {
        position = 0,
        immediate = 1,
        relative = 2,

        pub fn decode(num: usize) !Mode {
            for (Modes) |mode| {
                if (@intFromEnum(mode) == num) return mode;
            }
            return error.InvalidMode;
        }

        pub fn format(
            self: Mode,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            const c: u8 = switch (self) {
                .position => 'P',
                .immediate => 'I',
                .relative => 'R',
            };
            try writer.print("{c}", .{c});
        }
    };
    const Modes = std.meta.tags(Mode);

    code: std.ArrayList(isize),
    data: std.ArrayList(isize),
    pc: usize,
    halted: bool,
    base: i64,
    inp: Queue,
    out: Queue,

    pub fn init(allocator: Allocator) Computer {
        return .{
            .code = std.ArrayList(isize).init(allocator),
            .data = std.ArrayList(isize).init(allocator),
            .inp = Queue.init(allocator),
            .out = Queue.init(allocator),
            .pc = 0,
            .halted = false,
            .base = 0,
        };
    }

    pub fn deinit(self: *Computer) void {
        self.out.deinit();
        self.inp.deinit();
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
        self.halted = false;
        self.base = 0;
        self.inp.clearRetainingCapacity();
        self.out.clearRetainingCapacity();
    }

    fn enqueueInput(self: *Computer, input: isize) !void {
        try self.inp.appendTail(input);
    }

    fn dequeueOutput(self: *Computer) isize {
        return self.out.popHead() catch INFINITY;
    }

    pub fn runWithoutInput(self: *Computer) !void {
        try self.runWithInput(&[_]isize{});
    }

    pub fn runWithSingleInputAndReturnSingleValue(self: *Computer, input: isize) !isize {
        try self.runWithInput(&[_]isize{input});
        return self.dequeueOutput();
    }

    fn runWithInput(self: *Computer, input: []const isize) !void {
        try self.reset();
        for (input) |i| {
            try self.enqueueInput(i);
        }
        try self.run();
    }

    fn run(self: *Computer) !void {
        while (!self.halted) {
            var instr = self.getCurrentInstruction();
            const op = try Op.decode(instr % 100);
            instr /= 100;
            const m1 = try Mode.decode(instr % 10);
            instr /= 10;
            const m2 = try Mode.decode(instr % 10);
            instr /= 10;
            const m3 = try Mode.decode(instr % 10);
            instr /= 10;
            switch (op) {
                .halt => {
                    self.halted = true;
                    break;
                },
                .add => {
                    const v1 = self.readDecoded(1, m1);
                    const v2 = self.readDecoded(2, m2);
                    try self.writeDecoded(3, m3, v1 + v2);
                    self.incrPC(4);
                },
                .mul => {
                    const v1 = self.readDecoded(1, m1);
                    const v2 = self.readDecoded(2, m2);
                    try self.writeDecoded(3, m3, v1 * v2);
                    self.incrPC(4);
                },
                .rdsv => {
                    if (self.inp.empty()) {
                        break;
                    }
                    const v1 = try self.inp.popHead();
                    try self.writeDecoded(1, m1, v1);
                    self.incrPC(2);
                },
                .print => {
                    const v1 = self.readDecoded(1, m1);
                    try self.out.appendTail(v1);
                    self.incrPC(2);
                },
                .jit => {
                    const v1 = self.readDecoded(1, m1);
                    const v2 = self.readDecoded(2, m2);
                    if (v1 == 0) {
                        self.incrPC(3);
                    } else {
                        self.setPC(v2);
                    }
                },
                .jif => {
                    const v1 = self.readDecoded(1, m1);
                    const v2 = self.readDecoded(2, m2);
                    if (v1 == 0) {
                        self.setPC(v2);
                    } else {
                        self.incrPC(3);
                    }
                },
                .clt => {
                    const v1 = self.readDecoded(1, m1);
                    const v2 = self.readDecoded(2, m2);
                    try self.writeDecoded(3, m3, if (v1 < v2) 1 else 0);
                    self.incrPC(4);
                },
                .ceq => {
                    const v1 = self.readDecoded(1, m1);
                    const v2 = self.readDecoded(2, m2);
                    try self.writeDecoded(3, m3, if (v1 == v2) 1 else 0);
                    self.incrPC(4);
                },
                .rbo => {
                    const v1 = self.readDecoded(1, m1);
                    self.base += v1;
                    self.pc += 2;
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
        const addr: usize = @intCast(pos);
        const len = self.data.items.len;
        if (addr >= len) return 0;
        return self.data.items[addr];
    }

    fn setData(self: *Computer, pos: isize, val: isize) !void {
        const addr: usize = @intCast(pos);
        const len = self.data.items.len;
        if (addr >= len) {
            var new: usize = if (len == 0) 1 else len;
            while (new <= addr + 1) {
                new *= 2;
            }
            try self.data.ensureTotalCapacity(new);
            for (len..new) |_| {
                try self.data.append(0);
            }
        }
        self.data.items[addr] = val;
    }

    fn setPC(self: *Computer, pc: isize) void {
        self.pc = @intCast(pc);
    }

    fn incrPC(self: *Computer, delta: usize) void {
        self.pc += delta;
    }

    fn readDecoded(self: Computer, offset: usize, mode: Mode) isize {
        const pos = self.getOffset(offset);
        return switch (mode) {
            .position => self.getData(pos),
            .immediate => pos,
            .relative => self.getData(pos + self.base),
        };
    }

    fn writeDecoded(self: *Computer, offset: usize, mode: Mode, value: isize) !void {
        const pos = self.getOffset(offset);
        switch (mode) {
            .position => try self.setData(pos, value),
            .immediate => return error.InvalidWriteMode,
            .relative => try self.setData(pos + self.base, value),
        }
    }
};

test "sample part 1 quine" {
    const data =
        \\109,1,204,-1,1001,100,1,100,1008,100,16,101,1006,101,0,99
    ;

    var computer = Computer.init(testing.allocator);
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.addLine(line);
    }

    try computer.runWithoutInput();
    try testing.expectEqual(computer.out.size(), computer.code.items.len);
    var ok = true;
    for (0..computer.code.items.len) |p| {
        const d = computer.dequeueOutput();
        if (d != computer.code.items[p]) {
            ok = false;
            break;
        }
    }
    try testing.expect(ok);
}

test "sample part 1 16 digit number" {
    const data =
        \\1102,34915192,34915192,7,4,7,99,0
    ;

    var computer = Computer.init(testing.allocator);
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.addLine(line);
    }

    try computer.runWithoutInput();
    try testing.expectEqual(computer.out.size(), 1);
    const d = computer.dequeueOutput();
    try testing.expectEqual(d, 1219070632396864);
}

test "sample part 1 large number in the middle" {
    const data =
        \\104,1125899906842624,99
    ;

    var computer = Computer.init(testing.allocator);
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.addLine(line);
    }

    try computer.runWithoutInput();
    try testing.expectEqual(computer.out.size(), 1);
    const d = computer.dequeueOutput();
    try testing.expectEqual(d, 1125899906842624);
}
