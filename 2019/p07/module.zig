const std = @import("std");
const testing = std.testing;
const DoubleEndedQueue = @import("./util/queue.zig").DoubleEndedQueue;

const Allocator = std.mem.Allocator;

pub const Computer = struct {
    const Queue = DoubleEndedQueue(isize);

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
    halted: bool,
    inp: Queue,
    out: Queue,

    pub fn init(allocator: Allocator) Computer {
        return .{
            .code = std.ArrayList(isize).init(allocator),
            .data = std.ArrayList(isize).init(allocator),
            .pc = 0,
            .halted = false,
            .inp = Queue.init(allocator),
            .out = Queue.init(allocator),
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
        self.inp.clearRetainingCapacity();
        self.out.clearRetainingCapacity();
    }

    fn enqueueInput(self: *Computer, input: isize) !void {
        try self.inp.appendTail(input);
    }

    fn dequeueOutput(self: *Computer) ?isize {
        return self.out.popHead() catch null;
    }

    fn run(self: *Computer) !?isize {
        while (!self.halted) {
            var instr = self.getCurrentInstruction();
            const op = try Op.decode(instr % 100);
            instr /= 100;
            const m1 = try Mode.decode(instr % 10);
            instr /= 10;
            const m2 = try Mode.decode(instr % 10);
            instr /= 10;
            switch (op) {
                .halt => {
                    self.halted = true;
                    break;
                },
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
                    if (self.inp.empty()) {
                        // std.debug.print("{} | RDSV: PAUSED\n", .{self.pc});
                        break;
                    }
                    const p1 = self.getOffset(1);
                    self.setData(p1, try self.inp.popHead());
                    self.incrPC(2);
                },
                .print => {
                    const v1 = self.decodeValue(1, m1);
                    try self.out.appendTail(v1);
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
        return self.dequeueOutput();
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

pub const Cluster = struct {
    const SIZE = 5;

    amplifiers: [SIZE]Computer,

    pub fn init(allocator: Allocator) Cluster {
        var self = Cluster{
            .amplifiers = undefined,
        };
        for (0..SIZE) |a| {
            self.amplifiers[a] = Computer.init(allocator);
        }
        return self;
    }

    pub fn deinit(self: *Cluster) void {
        for (0..SIZE) |a| {
            self.amplifiers[a].deinit();
        }
    }

    pub fn addLine(self: *Cluster, line: []const u8) !void {
        for (0..SIZE) |a| {
            try self.amplifiers[a].addLine(line);
        }
    }

    pub fn reset(self: *Cluster) !void {
        for (0..SIZE) |a| {
            try self.amplifiers[a].reset();
        }
    }

    pub fn optimizeSignal(self: *Cluster, reentrant: bool) !isize {
        var phases: [5]isize = undefined; // must be sorted
        // It is a bit surprising that the only change we need between
        // part 1 (reentrant = false) and part 2 (reentrant = true) is
        // in the initial phases to permute -- so the algorithm written
        // for Computer.run() works equally well for both cases?
        if (reentrant) {
            phases = [_]isize{ 5, 6, 7, 8, 9 };
        } else {
            phases = [_]isize{ 0, 1, 2, 3, 4 };
        }
        return self.optimizeSignalForPhases(&phases);
    }

    fn optimizeSignalForPhases(self: *Cluster, phases: *[SIZE]isize) !isize {
        var best: isize = std.math.minInt(isize);
        try self.permutePhases(phases, SIZE, &best);
        return best;
    }

    fn permutePhases(self: *Cluster, phases: *[5]isize, len: usize, best: *isize) !void {
        if (len == 1) {
            const signal = try self.computeSignal(&phases.*);
            if (best.* < signal) {
                best.* = signal;
            }
            return;
        }

        for (0..SIZE) |pos| {
            const top = len - 1;
            std.mem.swap(isize, &phases[pos], &phases[top]);
            try self.permutePhases(phases, top, best);
            std.mem.swap(isize, &phases[pos], &phases[top]);
        }
    }

    fn computeSignal(self: *Cluster, phases: []const isize) !isize {
        try self.reset();
        for (0..SIZE) |a| {
            try self.amplifiers[a].enqueueInput(phases[a]);
        }
        var amplifier: usize = 0;
        var previous: ?isize = 0;
        var result: isize = 0;
        while (true) {
            if (self.amplifiers[amplifier].halted) {
                // The last amplifier seems to halt just once
                // for both part 1 and 2...
                if (amplifier == SIZE - 1) break;
            } else if (previous) |prv| {
                try self.amplifiers[amplifier].enqueueInput(prv);
                const output = try self.amplifiers[amplifier].run();
                if (output == null) {
                    std.debug.print("AMPLIFIER {} paused\n", .{amplifier});
                } else if (amplifier == SIZE - 1) {
                    result = output.?;
                }
                previous = output;
            } else {
                break;
            }
            amplifier += 1;
            amplifier %= SIZE;
        }
        return result;
    }
};

test "sample part 1, compute, short program" {
    const data =
        \\3,15,3,16,1002,16,10,16,1,16,15,15,4,15,99,0,0
    ;

    var cluster = Cluster.init(std.testing.allocator);
    defer cluster.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    const phases = [5]isize{ 4, 3, 2, 1, 0 };
    const signal = try cluster.computeSignal(&phases);
    const expected = @as(isize, 43210);
    try testing.expectEqual(expected, signal);
}

test "sample part 1, compute, medium program" {
    const data =
        \\3,23,3,24,1002,24,10,24,1002,23,-1,23,101
        \\5,23,23,1,24,23,23,4,23,99,0,0
    ;

    var cluster = Cluster.init(std.testing.allocator);
    defer cluster.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    const phases = [5]isize{ 0, 1, 2, 3, 4 };
    const signal = try cluster.computeSignal(&phases);
    const expected = @as(isize, 54321);
    try testing.expectEqual(expected, signal);
}

test "sample part 1, compute, long program" {
    const data =
        \\3,31,3,32,1002,32,10,32,1001,31,-2,31,1007,31,0,33
        \\1002,33,7,33,1,33,31,31,1,32,31,31,4,31,99,0,0,0
    ;

    var cluster = Cluster.init(std.testing.allocator);
    defer cluster.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    const phases = [5]isize{ 1, 0, 4, 3, 2 };
    const signal = try cluster.computeSignal(&phases);
    const expected = @as(isize, 65210);
    try testing.expectEqual(expected, signal);
}

test "sample part 1, optimize, short program" {
    const data =
        \\3,15,3,16,1002,16,10,16,1,16,15,15,4,15,99,0,0
    ;

    var cluster = Cluster.init(std.testing.allocator);
    defer cluster.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    const signal = try cluster.optimizeSignal(false);
    const expected = @as(isize, 43210);
    try testing.expectEqual(expected, signal);
}

test "sample part 1, optimize, medium program" {
    const data =
        \\3,23,3,24,1002,24,10,24,1002,23,-1,23,101
        \\5,23,23,1,24,23,23,4,23,99,0,0
    ;

    var cluster = Cluster.init(std.testing.allocator);
    defer cluster.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    const signal = try cluster.optimizeSignal(false);
    const expected = @as(isize, 54321);
    try testing.expectEqual(expected, signal);
}

test "sample part 1, optimize, long program" {
    const data =
        \\3,31,3,32,1002,32,10,32,1001,31,-2,31,1007,31,0,33
        \\1002,33,7,33,1,33,31,31,1,32,31,31,4,31,99,0,0,0
    ;

    var cluster = Cluster.init(std.testing.allocator);
    defer cluster.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    const signal = try cluster.optimizeSignal(false);
    const expected = @as(isize, 65210);
    try testing.expectEqual(expected, signal);
}

test "sample part 2, compute, long program" {
    const data =
        \\3,26,1001,26,-4,26,3,27,1002,27,2,27,1,27,26,27,4,27
        \\1001,28,-1,28,1005,28,6,99,0,0,5
    ;

    var cluster = Cluster.init(std.testing.allocator);
    defer cluster.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    const phases = [5]isize{ 9, 8, 7, 6, 5 };
    const signal = try cluster.computeSignal(&phases);
    const expected = @as(isize, 139629729);
    try testing.expectEqual(expected, signal);
}

test "sample part 2, compute, very long program" {
    const data =
        \\3,52,1001,52,-5,52,3,53,1,52,56,54,1007,54,5,55
        \\1005,55,26,1001,54,-5,54,1105,1,12,1,53,54,53
        \\1008,54,0,55,1001,55,1,55,2,53,55,53,4,53
        \\1001,56,-1,56,1005,56,6,99,0,0,0,0,10
    ;

    var cluster = Cluster.init(std.testing.allocator);
    defer cluster.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    const phases = [5]isize{ 9, 7, 8, 5, 6 };
    const signal = try cluster.computeSignal(&phases);
    const expected = @as(isize, 18216);
    try testing.expectEqual(expected, signal);
}

test "sample part 2, optimize, long program" {
    const data =
        \\3,26,1001,26,-4,26,3,27,1002,27,2,27,1,27
        \\26,27,4,27,1001,28,-1,28,1005,28,6,99,0,0,5
    ;

    var cluster = Cluster.init(std.testing.allocator);
    defer cluster.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    const signal = try cluster.optimizeSignal(true);
    const expected = @as(isize, 139629729);
    try testing.expectEqual(expected, signal);
}

test "sample part 2, optimize, very long program" {
    const data =
        \\3,52,1001,52,-5,52,3,53,1,52,56,54,1007
        \\54,5,55,1005,55,26,1001,54,-5,54,1105
        \\1,12,1,53,54,53,1008,54,0,55,1001,55
        \\1,55,2,53,55,53,4,53,1001,56,-1,56,1005
        \\56,6,99,0,0,0,0,10
    ;

    var cluster = Cluster.init(std.testing.allocator);
    defer cluster.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    const signal = try cluster.optimizeSignal(true);
    const expected = @as(isize, 18216);
    try testing.expectEqual(expected, signal);
}
