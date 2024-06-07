const std = @import("std");
const testing = std.testing;
const DoubleEndedQueue = @import("./util/queue.zig").DoubleEndedQueue;
const Math = @import("./util/math.zig").Math;
const UtilGrid = @import("./util/grid.zig");

const Allocator = std.mem.Allocator;

pub const Computer = struct {
    const Queue = DoubleEndedQueue(isize);
    const Data = std.ArrayList(isize);

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

    code: Data,
    data: Data,
    pc: usize,
    halted: bool,
    auto_reset: bool,
    base: isize,
    inp: Queue,
    out: Queue,

    pub fn init(allocator: Allocator) Computer {
        return .{
            .code = Data.init(allocator),
            .data = Data.init(allocator),
            .inp = Queue.init(allocator),
            .out = Queue.init(allocator),
            .pc = 0,
            .halted = false,
            .auto_reset = false,
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

    pub fn resetComputer(self: *Computer) !void {
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

    pub fn enqueueInput(self: *Computer, input: isize) !void {
        try self.inp.appendTail(input);
    }

    pub fn dequeueOutput(self: *Computer) ?isize {
        return self.out.popHead() catch null;
    }

    pub fn runWithoutInput(self: *Computer) !void {
        try self.runWithInput(&[_]isize{});
    }

    pub fn runWithSingleInputAndReturnSingleValue(self: *Computer, input: isize) !isize {
        try self.runWithInput(&[_]isize{input});
        return self.dequeueOutput();
    }

    fn runWithInput(self: *Computer, input: []const isize) !void {
        for (input) |i| {
            try self.enqueueInput(i);
        }
        try self.run();
    }

    fn run(self: *Computer) !void {
        if (self.auto_reset) try self.resetComputer();

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
                        // std.debug.print("COMPUTER pause\n", .{});
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
    const Pos = UtilGrid.Pos;
    const Grid = UtilGrid.SparseGrid(Tile);
    const Score = std.AutoHashMap(Pos, usize);
    const OFFSET = 500;

    pub const Dir = enum(u8) {
        N = 1,
        S = 2,
        W = 3,
        E = 4,

        pub fn reverse(dir: Dir) Dir {
            return switch (dir) {
                .N => .S,
                .S => .N,
                .W => .E,
                .E => .W,
            };
        }

        pub fn move(pos: Pos, dir: Dir) Pos {
            var nxt = pos;
            switch (dir) {
                .N => nxt.y -= 1,
                .S => nxt.y += 1,
                .W => nxt.x -= 1,
                .E => nxt.x += 1,
            }
            return nxt;
        }

        pub fn parse(c: u8) !Dir {
            const dir: Dir = switch (c) {
                'N' => .N,
                'S' => .S,
                'E' => .E,
                'W' => .W,
                else => return error.InvalidDir,
            };
            return dir;
        }

        pub fn format(
            dir: Dir,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("{s}", .{@tagName(dir)});
        }
    };
    const Dirs = std.meta.tags(Dir);

    pub const Status = enum(u8) {
        wall = 0,
        location = 1,
        target = 2,

        pub fn decode(n: isize) !Status {
            for (Statuses) |s| {
                if (@intFromEnum(s) == n) return s;
            }
            return error.InvalidStatus;
        }
    };
    const Statuses = std.meta.tags(Status);

    pub const Tile = enum(u8) {
        empty = ' ',
        wall = '#',
        oxygen = 'O',

        pub fn format(
            tile: Tile,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("{c}", .{@intFromEnum(tile)});
        }
    };

    allocator: Allocator,
    computer: Computer,
    grid: Grid,
    pos_oxygen: Pos,
    pos_current: Pos,

    pub fn init(allocator: Allocator) Ship {
        return .{
            .allocator = allocator,
            .computer = Computer.init(allocator),
            .grid = Grid.init(allocator, .empty),
            .pos_current = Pos.init(OFFSET / 2, OFFSET / 2),
            .pos_oxygen = undefined,
        };
    }

    pub fn deinit(self: *Ship) void {
        self.grid.deinit();
        self.computer.deinit();
    }

    pub fn show(self: Ship) void {
        std.debug.print("MAP: {} x {} - {} {} - {} {} - Oxygen at {}\n", .{
            self.grid.max.x - self.grid.min.x + 1,
            self.grid.max.y - self.grid.min.y + 1,
            self.grid.min.x,
            self.grid.min.y,
            self.grid.max.x,
            self.grid.max.y,
            self.pos_oxygen,
        });
        var y: isize = self.grid.min.y;
        while (y <= self.grid.max.y) : (y += 1) {
            const uy: usize = @intCast(y);
            std.debug.print("{:>4} | ", .{uy});
            var x: isize = self.grid.min.x;
            while (x <= self.grid.max.x) : (x += 1) {
                const pos = Pos.init(x, y);
                var label: u8 = @intFromEnum(self.grid.get(pos));
                if (pos.equal(self.pos_oxygen)) {
                    label = 'O';
                }
                if (pos.equal(self.pos_current)) {
                    label = 'D';
                }
                std.debug.print("{c}", .{label});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn addLine(self: *Ship, line: []const u8) !void {
        try self.computer.addLine(line);
    }

    pub fn discoverOxygen(self: *Ship) !usize {
        try self.walkAround();
        return try self.findPathToTarget();
    }

    pub fn measureTimeToFillWithOxygen(self: *Ship) !usize {
        try self.walkAround();
        return try self.fillWithOxygen();
    }

    fn walkAround(self: *Ship) !void {
        var seen = Score.init(self.allocator);
        defer seen.deinit();
        try self.computer.resetComputer();
        try self.markAndWalk(.empty, &seen);
        // self.show();
    }

    fn markAndWalk(self: *Ship, mark: Tile, seen: *Score) !void {
        _ = try self.grid.set(self.pos_current, mark);
        _ = try seen.getOrPut(self.pos_current);
        if (mark != .empty) return;

        const pos_original = self.pos_current;
        for (Dirs) |d| {
            const r = Dir.reverse(d);
            self.pos_current = Dir.move(pos_original, d);
            if (seen.contains(self.pos_current)) continue;

            const status = try self.tryMove(d);
            switch (status) {
                .wall => try self.markAndWalk(.wall, seen),
                .location => {
                    try self.markAndWalk(.empty, seen);
                    _ = try self.tryMove(r);
                },
                .target => {
                    self.pos_oxygen = self.pos_current;
                    try self.markAndWalk(.empty, seen);
                    _ = try self.tryMove(r);
                },
            }
        }
        self.pos_current = pos_original;
    }

    fn tryMove(self: *Ship, d: Dir) !Status {
        try self.computer.enqueueInput(@intFromEnum(d));
        try self.computer.run();
        if (self.computer.dequeueOutput()) |output| {
            return try Status.decode(output);
        }
        return error.MissingOutput;
    }

    fn CmpScorePos(fScore: *Score, l: Pos, r: Pos) std.math.Order {
        const le = fScore.*.get(l) orelse Math.INFINITY;
        const re = fScore.*.get(r) orelse Math.INFINITY;
        const oe = std.math.order(le, re);
        if (oe != .eq) return oe;
        if (l.x < r.x) return .lt;
        if (l.x > r.x) return .gt;
        if (l.y < r.y) return .lt;
        if (l.y > r.y) return .gt;
        return .eq;
    }

    fn findPathToTarget(self: *Ship) !usize {
        const PQ = std.PriorityQueue(Pos, *Score, CmpScorePos);
        var fScore = Score.init(self.allocator);
        defer fScore.deinit();
        var gScore = Score.init(self.allocator);
        defer gScore.deinit();
        var openSet = PQ.init(self.allocator, &fScore);
        defer openSet.deinit();

        const start = self.pos_current;
        try self.recordState(start, 0, &fScore, &gScore);
        _ = try openSet.add(start);

        while (openSet.count() != 0) {
            const cpos = openSet.remove();
            const cg = gScore.get(cpos) orelse return error.InconsistentScore;
            if (cpos.equal(self.pos_oxygen)) {
                return cg;
            }
            for (Dirs) |d| {
                const npos = Dir.move(cpos, d);
                if (self.grid.get(npos) != .empty) continue;
                var ng: usize = Math.INFINITY;
                if (gScore.get(npos)) |v| ng = v;
                const tentative = cg + 1;
                if (tentative >= ng) continue;
                try self.recordState(npos, tentative, &fScore, &gScore);
                _ = try openSet.add(npos);
            }
        }
        return 0;
    }

    fn recordState(self: Ship, state: Pos, g: usize, fScore: *Score, gScore: *Score) !void {
        const h = state.manhattanDist(self.pos_oxygen);
        try gScore.put(state, g);
        try fScore.put(state, g + h);
    }

    const State = struct {
        pos: Pos,
        dist: usize,

        pub fn init(pos: Pos, dist: usize) State {
            return .{
                .pos = pos,
                .dist = dist,
            };
        }
    };

    // https://en.wikipedia.org/wiki/Flood_fill
    // Basically a BFS walk, remembering the distance to the source
    fn fillWithOxygen(self: *Ship) !usize {
        const Queue = DoubleEndedQueue(State);
        var queue = Queue.init(self.allocator);
        defer queue.deinit();
        var seen = Score.init(self.allocator);
        defer seen.deinit();

        // We start from the oxygen system position, which has already been filled with oxygen
        var steps: usize = 0;
        try queue.appendTail(State.init(self.pos_oxygen, 0));
        while (!queue.empty()) {
            const current = try queue.popHead();
            const r = try seen.getOrPut(current.pos);
            if (r.found_existing) continue;
            if (steps < current.dist) {
                steps = current.dist;
            }
            for (Dirs) |d| {
                const npos = Dir.move(current.pos, d);
                if (self.grid.get(npos) != .empty) continue;
                try queue.appendTail(State.init(npos, current.dist + 1));
            }
        }
        return steps;
    }
};
