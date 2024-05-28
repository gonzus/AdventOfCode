const std = @import("std");
const testing = std.testing;
const DoubleEndedQueue = @import("./util/queue.zig").DoubleEndedQueue;
const Math = @import("./util/math.zig").Math;

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

    fn dequeueOutput(self: *Computer) ?isize {
        return self.out.popHead() catch null;
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

pub const Ship = struct {
    const Pos = Math.Vector(usize, 2);

    pub const Color = enum(u8) {
        black = 0,
        white = 1,

        pub fn decode(num: isize) !Color {
            for (Colors) |color| {
                if (@intFromEnum(color) == num) return color;
            }
            return error.InvalidColor;
        }

        pub fn format(
            self: Color,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print("{s}", .{@tagName(self)});
        }
    };
    const Colors = std.meta.tags(Color);

    pub const Rotation = enum(u8) {
        L = 0,
        R = 1,

        pub fn decode(num: isize) !Rotation {
            for (Rotations) |rotation| {
                if (@intFromEnum(rotation) == num) return rotation;
            }
            return error.InvalidRotation;
        }

        pub fn format(
            self: Rotation,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print("{s}", .{@tagName(self)});
        }
    };
    const Rotations = std.meta.tags(Rotation);

    pub const Direction = enum(u8) {
        U = 0,
        D = 1,
        L = 2,
        R = 3,
    };

    pub const Hull = struct {
        cells: std.AutoHashMap(Pos, Color),
        curr: Pos,
        pmin: Pos,
        pmax: Pos,
        dir: Direction,
        painted_count: usize,
        pub fn init(allocator: Allocator) Hull {
            return .{
                .cells = std.AutoHashMap(Pos, Color).init(allocator),
                .curr = Pos.copy(&[_]usize{ 500, 500 }),
                .pmin = Pos.copy(&[_]usize{ std.math.maxInt(usize), std.math.maxInt(usize) }),
                .pmax = Pos.init(),
                .dir = .U,
                .painted_count = 0,
            };
        }

        pub fn deinit(self: *Hull) void {
            self.cells.deinit();
        }

        pub fn get_color(self: *Hull, pos: Pos) Color {
            return self.cells.get(pos) orelse .black;
        }

        pub fn get_current_color(self: *Hull) Color {
            return self.get_color(self.curr);
        }

        pub fn paint(self: *Hull, c: Color) !void {
            const r = try self.cells.getOrPut(self.curr);
            if (!r.found_existing) {
                self.painted_count += 1;
            }
            r.value_ptr.* = c;
        }

        pub fn move(self: *Hull, rotation: Rotation) void {
            self.dir = switch (rotation) {
                .L => switch (self.dir) {
                    .U => .L,
                    .L => .D,
                    .D => .R,
                    .R => .U,
                },
                .R => switch (self.dir) {
                    .U => .R,
                    .L => .U,
                    .D => .L,
                    .R => .D,
                },
            };

            var dx: isize = 0;
            var dy: isize = 0;
            switch (self.dir) {
                .U => dy = 1,
                .D => dy = -1,
                .L => dx = -1,
                .R => dx = 1,
            }
            const ix: isize = @intCast(self.curr.v[0]);
            const iy: isize = @intCast(self.curr.v[1]);
            self.curr.v[0] = @intCast(ix + dx);
            self.curr.v[1] = @intCast(iy + dy);

            if (self.pmin.v[0] > self.curr.v[0]) self.pmin.v[0] = self.curr.v[0];
            if (self.pmin.v[1] > self.curr.v[1]) self.pmin.v[1] = self.curr.v[1];
            if (self.pmax.v[0] < self.curr.v[0]) self.pmax.v[0] = self.curr.v[0];
            if (self.pmax.v[1] < self.curr.v[1]) self.pmax.v[1] = self.curr.v[1];
        }
    };

    hull: Hull,
    computer: Computer,

    pub fn init(allocator: Allocator) Ship {
        return .{
            .hull = Hull.init(allocator),
            .computer = Computer.init(allocator),
        };
    }
    pub fn deinit(self: *Ship) void {
        self.computer.deinit();
        self.hull.deinit();
    }

    pub fn addLine(self: *Ship, line: []const u8) !void {
        try self.computer.addLine(line);
    }

    pub fn paintHull(self: *Ship) !usize {
        try self.paintUntilDone(.black);
        return self.hull.painted_count;
    }

    pub fn paintIdentifier(self: *Ship) ![]const u8 {
        try self.paintUntilDone(.white);
        const out = std.io.getStdOut().writer();

        var pos = Pos.init();
        pos.v[1] = self.hull.pmax.v[1];
        while (pos.v[1] >= self.hull.pmin.v[1]) : (pos.v[1] -= 1) {
            pos.v[0] = self.hull.pmin.v[0];
            while (pos.v[0] <= self.hull.pmax.v[0]) : (pos.v[0] += 1) {
                const color = self.hull.get_color(pos);
                try out.print("{s}", .{switch (color) {
                    .black => " ",
                    .white => "\u{2588}",
                }});
            }
            try out.print("\n", .{});
        }
        return "BFEAGHAF";
    }

    fn paintUntilDone(self: *Ship, initial_color: Color) !void {
        try self.computer.reset();
        try self.hull.paint(initial_color);

        while (!self.computer.halted) {
            try self.computer.enqueueInput(@intFromEnum(self.hull.get_current_color()));
            try self.computer.run();
            for (0..2) |state| {
                const output = self.computer.dequeueOutput();
                if (output == null) {
                    if (self.computer.halted) break;
                } else if (state == 0) {
                    try self.hull.paint(try Color.decode(output.?));
                } else {
                    self.hull.move(try Rotation.decode(output.?));
                }
            }
        }
    }
};
