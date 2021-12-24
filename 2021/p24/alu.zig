const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const ALU = struct {
    const NUM_VARS = 4;
    const NUM_STAGES = 14;
    const NUM_INSTR = 10;
    const INSTR_PER_STAGE = 18;

    pub const OP = enum {
        INP,
        ADD,
        MUL,
        DIV,
        MOD,
        EQL,

        pub fn parse(str: []const u8) OP {
            if (std.mem.eql(u8, str, "inp")) return .INP;
            if (std.mem.eql(u8, str, "add")) return .ADD;
            if (std.mem.eql(u8, str, "mul")) return .MUL;
            if (std.mem.eql(u8, str, "div")) return .DIV;
            if (std.mem.eql(u8, str, "mod")) return .MOD;
            if (std.mem.eql(u8, str, "eql")) return .EQL;
            unreachable;
        }
    };

    pub const Instruction = struct {
        op: OP,
        v0: usize,
        v1: usize,
        n1: isize,

        pub fn init(op: OP, v0: usize, v1: usize, n1: isize) Instruction {
            var self = Instruction{
                .op = op,
                .v0 = v0,
                .v1 = v1,
                .n1 = n1,
            };
            return self;
        }
    };

    pub const Simulator = struct {
        code: [1024]Instruction,
        nc: usize,
        vars: [NUM_VARS]isize,

        pub fn init() Simulator {
            var self = Simulator{
                .code = undefined,
                .nc = 0,
                .vars = [_]isize{0} ** NUM_VARS,
            };
            return self;
        }

        pub fn deinit(_: *Simulator) void {}

        pub fn get_var(self: Simulator, v: u8) isize {
            return self.vars[v - 'w'];
        }

        pub fn reset(self: *Simulator, vars: [NUM_VARS]isize) void {
            self.vars = vars;
        }

        pub fn clear(self: *Simulator) void {
            self.reset([_]isize{0} ** NUM_VARS);
        }

        pub fn run(self: *Simulator, input: []const u8) bool {
            var pi: usize = 0;
            var pc: usize = 0;
            while (pc < self.nc) : (pc += 1) {
                const i = self.code[pc];
                switch (i.op) {
                    .INP => {
                        self.vars[i.v0] = input[pi] - '0';
                        pi += 1;
                    },
                    .ADD => {
                        const val = if (i.v1 >= NUM_VARS) i.n1 else self.vars[i.v1];
                        self.vars[i.v0] += val;
                    },
                    .MUL => {
                        const val = if (i.v1 >= NUM_VARS) i.n1 else self.vars[i.v1];
                        self.vars[i.v0] *= val;
                    },
                    .DIV => {
                        const val = if (i.v1 >= NUM_VARS) i.n1 else self.vars[i.v1];
                        if (val == 0) return false;
                        self.vars[i.v0] = @divTrunc(self.vars[i.v0], val);
                    },
                    .MOD => {
                        if (self.vars[i.v0] < 0) return false;
                        const val = if (i.v1 >= NUM_VARS) i.n1 else self.vars[i.v1];
                        if (val <= 0) return false;
                        self.vars[i.v0] = @rem(self.vars[i.v0], val);
                    },
                    .EQL => {
                        const val = if (i.v1 >= NUM_VARS) i.n1 else self.vars[i.v1];
                        self.vars[i.v0] = if (self.vars[i.v0] == val) 1 else 0;
                    },
                }
                // std.debug.warn("PC {}: VARS {d}\n", .{ pc, self.vars });
            }
            return true;
        }
    };

    power10: [NUM_STAGES]isize,
    values: [NUM_STAGES][NUM_INSTR]isize,
    cache: [NUM_STAGES]std.AutoHashMap(isize, isize),
    stage: usize,
    sim: Simulator,

    pub fn init() ALU {
        var self = ALU{
            .power10 = undefined,
            .values = undefined,
            .cache = undefined,
            .stage = 0,
            .sim = Simulator.init(),
        };
        for (self.cache) |*c| {
            c.* = std.AutoHashMap(isize, isize).init(allocator);
        }
        for (self.power10) |*p, j| {
            if (j == 0) {
                p.* = 1;
                continue;
            }
            p.* = 10 * self.power10[j - 1];
        }
        return self;
    }

    pub fn deinit(self: *ALU) void {
        self.sim.deinit();
        for (self.cache) |*c| {
            c.*.deinit();
        }
    }

    pub fn process_line(self: *ALU, data: []const u8) !void {
        var op: OP = undefined;
        var v0: usize = 0;
        var v1: usize = 0;
        var n1: isize = 0;
        var p: usize = 0;
        var it = std.mem.tokenize(u8, data, " ");
        while (it.next()) |str| : (p += 1) {
            if (p == 0) {
                op = OP.parse(str);
                continue;
            }
            if (p == 1 or p == 2) {
                if (str[0] == '-' or (str[0] >= '0' and str[0] <= '9')) {
                    if (p == 1) unreachable;
                    n1 = std.fmt.parseInt(isize, str, 10) catch unreachable;
                    v1 = 255;
                } else {
                    if (p == 1) {
                        v0 = str[0] - 'w';
                    }
                    if (p == 2) {
                        v1 = str[0] - 'w';
                        n1 = 0;
                    }
                }
            }
            if (p == 1 and op != .INP) continue;

            if (op == .INP) self.stage += 1;

            self.sim.code[self.sim.nc] = Instruction.init(op, v0, v1, n1);
            // std.debug.warn("INSTRUCTION {}: {}\n", .{ self.sim.nc, self.sim.code[self.sim.nc] });

            const k: usize = switch (self.sim.nc % INSTR_PER_STAGE) {
                1 => 0,
                3 => 1,
                4 => 2,
                5 => 3,
                7 => 4,
                8 => 5,
                9 => 6,
                11 => 7,
                13 => 8,
                15 => 9,
                else => std.math.maxInt(usize),
            };
            if (k != std.math.maxInt(usize)) self.values[self.stage - 1][k] = n1;
            self.sim.nc += 1;
            continue;
        }
    }

    const SearchErrors = error{OutOfMemory};

    pub fn search_max(self: *ALU) SearchErrors!usize {
        const found = try self.search_from(0, 0, 9, -1, -1);
        if (found < 0) return 0;
        return @intCast(usize, found);
    }

    pub fn search_min(self: *ALU) SearchErrors!usize {
        const found = try self.search_from(0, 0, 1, 10, 1);
        if (found < 0) return 0;
        return @intCast(usize, found);
    }

    pub fn search_from(self: *ALU, index: usize, z: isize, w0: isize, w1: isize, dw: isize) SearchErrors!isize {
        // reached the end!
        if (index == NUM_STAGES) {
            if (z == 0) {
                return 0; // yay!
            }
            return -1;
        }

        // read cache
        const entry = self.cache[index].getEntry(z);
        if (entry) |e| return e.value_ptr.*;

        var w: isize = w0;
        while (w != w1) : (w += dw) {
            var nx = z;
            if (nx < 0 or self.values[index][1] <= 0) continue;

            nx = @rem(nx, self.values[index][1]);
            if (self.values[index][2] == 0) continue;

            var nz = @divTrunc(z, self.values[index][2]);
            nx += self.values[index][3];
            nx = if (nx == w) 1 else 0;
            nx = if (nx == self.values[index][4]) 1 else 0;

            var ny = self.values[index][6];
            ny *= nx;
            ny += self.values[index][7];
            nz *= ny;
            ny *= self.values[index][8];
            ny += w;
            ny += self.values[index][9];
            ny *= nx;
            nz += ny;

            const t = try self.search_from(index + 1, nz, w0, w1, dw);
            if (t == -1) continue;

            const v = t + w * self.power10[NUM_STAGES - 1 - index];
            try self.cache[index].put(z, v);
            return v;
        }

        // failed, remember and return
        try self.cache[index].put(z, -1);
        return -1;
    }
};

test "sample part a small 1" {
    const data: []const u8 =
        \\inp x
        \\mul x -1
    ;

    var alu = ALU.init();
    defer alu.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try alu.process_line(line);
    }

    const ok = alu.sim.run("7");
    try testing.expect(ok);
    try testing.expect(alu.sim.get_var('x') == -7);
}

test "sample part a small 2" {
    const data: []const u8 =
        \\inp w
        \\add z w
        \\mod z 2
        \\div w 2
        \\add y w
        \\mod y 2
        \\div w 2
        \\add x w
        \\mod x 2
        \\div w 2
        \\mod w 2
    ;

    var alu = ALU.init();
    defer alu.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try alu.process_line(line);
    }

    {
        alu.sim.clear();
        const ok = alu.sim.run("9");
        try testing.expect(ok);
        try testing.expect(alu.sim.get_var('w') == 1);
        try testing.expect(alu.sim.get_var('x') == 0);
        try testing.expect(alu.sim.get_var('y') == 0);
        try testing.expect(alu.sim.get_var('z') == 1);
    }
    {
        alu.sim.clear();
        const ok = alu.sim.run("7");
        try testing.expect(ok);
        try testing.expect(alu.sim.get_var('w') == 0);
        try testing.expect(alu.sim.get_var('x') == 1);
        try testing.expect(alu.sim.get_var('y') == 1);
        try testing.expect(alu.sim.get_var('z') == 1);
    }
    {
        alu.sim.clear();
        const ok = alu.sim.run("4");
        try testing.expect(ok);
        try testing.expect(alu.sim.get_var('w') == 0);
        try testing.expect(alu.sim.get_var('x') == 1);
        try testing.expect(alu.sim.get_var('y') == 0);
        try testing.expect(alu.sim.get_var('z') == 0);
    }
    {
        alu.sim.clear();
        const ok = alu.sim.run("1");
        try testing.expect(ok);
        try testing.expect(alu.sim.get_var('w') == 0);
        try testing.expect(alu.sim.get_var('x') == 0);
        try testing.expect(alu.sim.get_var('y') == 0);
        try testing.expect(alu.sim.get_var('z') == 1);
    }
    {
        alu.sim.clear();
        const ok = alu.sim.run("0");
        try testing.expect(ok);
        try testing.expect(alu.sim.get_var('w') == 0);
        try testing.expect(alu.sim.get_var('x') == 0);
        try testing.expect(alu.sim.get_var('y') == 0);
        try testing.expect(alu.sim.get_var('z') == 0);
    }
}

test "sample parts a & b" {
    const data: []const u8 =
        \\inp w
        \\mul x 0
        \\add x z
        \\mod x 26
        \\div z 1
        \\add x 13
        \\eql x w
        \\eql x 0
        \\mul y 0
        \\add y 25
        \\mul y x
        \\add y 1
        \\mul z y
        \\mul y 0
        \\add y w
        \\add y 15
        \\mul y x
        \\add z y
        \\inp w
        \\mul x 0
        \\add x z
        \\mod x 26
        \\div z 1
        \\add x 13
        \\eql x w
        \\eql x 0
        \\mul y 0
        \\add y 25
        \\mul y x
        \\add y 1
        \\mul z y
        \\mul y 0
        \\add y w
        \\add y 16
        \\mul y x
        \\add z y
        \\inp w
        \\mul x 0
        \\add x z
        \\mod x 26
        \\div z 1
        \\add x 10
        \\eql x w
        \\eql x 0
        \\mul y 0
        \\add y 25
        \\mul y x
        \\add y 1
        \\mul z y
        \\mul y 0
        \\add y w
        \\add y 4
        \\mul y x
        \\add z y
        \\inp w
        \\mul x 0
        \\add x z
        \\mod x 26
        \\div z 1
        \\add x 15
        \\eql x w
        \\eql x 0
        \\mul y 0
        \\add y 25
        \\mul y x
        \\add y 1
        \\mul z y
        \\mul y 0
        \\add y w
        \\add y 14
        \\mul y x
        \\add z y
        \\inp w
        \\mul x 0
        \\add x z
        \\mod x 26
        \\div z 26
        \\add x -8
        \\eql x w
        \\eql x 0
        \\mul y 0
        \\add y 25
        \\mul y x
        \\add y 1
        \\mul z y
        \\mul y 0
        \\add y w
        \\add y 1
        \\mul y x
        \\add z y
        \\inp w
        \\mul x 0
        \\add x z
        \\mod x 26
        \\div z 26
        \\add x -10
        \\eql x w
        \\eql x 0
        \\mul y 0
        \\add y 25
        \\mul y x
        \\add y 1
        \\mul z y
        \\mul y 0
        \\add y w
        \\add y 5
        \\mul y x
        \\add z y
        \\inp w
        \\mul x 0
        \\add x z
        \\mod x 26
        \\div z 1
        \\add x 11
        \\eql x w
        \\eql x 0
        \\mul y 0
        \\add y 25
        \\mul y x
        \\add y 1
        \\mul z y
        \\mul y 0
        \\add y w
        \\add y 1
        \\mul y x
        \\add z y
        \\inp w
        \\mul x 0
        \\add x z
        \\mod x 26
        \\div z 26
        \\add x -3
        \\eql x w
        \\eql x 0
        \\mul y 0
        \\add y 25
        \\mul y x
        \\add y 1
        \\mul z y
        \\mul y 0
        \\add y w
        \\add y 3
        \\mul y x
        \\add z y
        \\inp w
        \\mul x 0
        \\add x z
        \\mod x 26
        \\div z 1
        \\add x 14
        \\eql x w
        \\eql x 0
        \\mul y 0
        \\add y 25
        \\mul y x
        \\add y 1
        \\mul z y
        \\mul y 0
        \\add y w
        \\add y 3
        \\mul y x
        \\add z y
        \\inp w
        \\mul x 0
        \\add x z
        \\mod x 26
        \\div z 26
        \\add x -4
        \\eql x w
        \\eql x 0
        \\mul y 0
        \\add y 25
        \\mul y x
        \\add y 1
        \\mul z y
        \\mul y 0
        \\add y w
        \\add y 7
        \\mul y x
        \\add z y
        \\inp w
        \\mul x 0
        \\add x z
        \\mod x 26
        \\div z 1
        \\add x 14
        \\eql x w
        \\eql x 0
        \\mul y 0
        \\add y 25
        \\mul y x
        \\add y 1
        \\mul z y
        \\mul y 0
        \\add y w
        \\add y 5
        \\mul y x
        \\add z y
        \\inp w
        \\mul x 0
        \\add x z
        \\mod x 26
        \\div z 26
        \\add x -5
        \\eql x w
        \\eql x 0
        \\mul y 0
        \\add y 25
        \\mul y x
        \\add y 1
        \\mul z y
        \\mul y 0
        \\add y w
        \\add y 13
        \\mul y x
        \\add z y
        \\inp w
        \\mul x 0
        \\add x z
        \\mod x 26
        \\div z 26
        \\add x -8
        \\eql x w
        \\eql x 0
        \\mul y 0
        \\add y 25
        \\mul y x
        \\add y 1
        \\mul z y
        \\mul y 0
        \\add y w
        \\add y 3
        \\mul y x
        \\add z y
        \\inp w
        \\mul x 0
        \\add x z
        \\mod x 26
        \\div z 26
        \\add x -11
        \\eql x w
        \\eql x 0
        \\mul y 0
        \\add y 25
        \\mul y x
        \\add y 1
        \\mul z y
        \\mul y 0
        \\add y w
        \\add y 10
        \\mul y x
        \\add z y
    ;

    var alu = ALU.init();
    defer alu.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try alu.process_line(line);
    }

    {
        alu.sim.clear();
        const ok = alu.sim.run("51939397989999");
        try testing.expect(ok);
        try testing.expect(alu.sim.get_var('z') == 0);
    }
    {
        alu.sim.clear();
        const ok = alu.sim.run("11717131211195");
        try testing.expect(ok);
        try testing.expect(alu.sim.get_var('z') == 0);
    }
}
