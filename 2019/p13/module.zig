const std = @import("std");
const testing = std.testing;
const DoubleEndedQueue = @import("./util/queue.zig").DoubleEndedQueue;
const Math = @import("./util/math.zig").Math;
const DenseGrid = @import("./util/grid.zig").DenseGrid;

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
    auto_reset: bool,
    base: isize,
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

pub const Arcade = struct {
    const Grid = DenseGrid(Tile);
    const Pos = Math.Vector(isize, 2);

    pub const Tile = enum(isize) {
        empty = 0,
        wall = 1,
        block = 2,
        paddle = 3,
        ball = 4,

        pub fn decode(num: isize) !Tile {
            for (Tiles) |tile| {
                if (@intFromEnum(tile) == num) return tile;
            }
            return error.InvalidTile;
        }
        pub fn format(
            tile: Tile,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            const c: u8 = switch (tile) {
                .empty => ' ',
                .wall => 'X',
                .block => '#',
                .paddle => '-',
                .ball => 'O',
            };
            _ = try writer.print("{c}", .{c});
        }
    };
    const Tiles = std.meta.tags(Tile);

    pub const State = enum {
        pos_x,
        pos_y,
        tile,
    };

    cells: Grid,
    computer: Computer,
    next: Pos,
    state: State,
    paddle: Pos,
    score: usize,

    pub fn init(allocator: Allocator) Arcade {
        return .{
            .cells = Grid.init(allocator, .empty),
            .computer = Computer.init(allocator),
            .next = Pos.init(),
            .paddle = Pos.init(),
            .state = .pos_x,
            .score = 0,
        };
    }

    pub fn deinit(self: *Arcade) void {
        self.computer.deinit();
        self.cells.deinit();
    }

    pub fn addLine(self: *Arcade, line: []const u8) !void {
        try self.computer.addLine(line);
    }

    pub fn show(self: Arcade) !void {
        const out = std.io.getStdOut().writer();
        const escape: u8 = 0o33;
        try out.print("{c}[2J{c}[H", .{ escape, escape });
        for (0..self.cells.rows()) |y| {
            for (0..self.cells.cols()) |x| {
                const tile = self.cells.get(x, y);
                try out.print("{}", .{tile});
            }
            try out.print("\n", .{});
        }
        try out.print("Grid {}x{}, score: {}\n", .{
            self.cells.rows(),
            self.cells.cols(),
            self.score,
        });
    }

    pub fn runAndCountBlockTiles(self: *Arcade) !usize {
        try self.computer.resetComputer();
        try self.run();
        return self.count_tiles(.block);
    }

    pub fn runWithHackedCodeAndReturnScore(self: *Arcade, coins: isize) !usize {
        try self.computer.resetComputer();
        self.computer.data.items[0] = coins;
        try self.run();
        return self.score;
    }

    fn run(self: *Arcade) !void {
        while (true) {
            try self.computer.runWithoutInput();
            while (true) {
                if (self.computer.dequeueOutput()) |output| {
                    try self.processOutput(output);
                } else {
                    break;
                }
            }
            // try self.show();
            if (self.computer.halted) {
                break;
            }
        }
    }

    fn processOutput(self: *Arcade, output: isize) !void {
        switch (self.state) {
            .pos_x => {
                self.next.v[0] = output;
                self.state = .pos_y;
            },
            .pos_y => {
                self.next.v[1] = output;
                self.state = .tile;
            },
            .tile => {
                if (self.next.v[0] == -1 and self.next.v[1] == 0) {
                    self.score = @intCast(output);
                } else {
                    const tile = try Tile.decode(output);
                    try self.put_tile(self.next, tile);
                }
                self.state = .pos_x;
            },
        }
    }

    pub fn put_tile(self: *Arcade, pos: Pos, tile: Tile) !void {
        const x: usize = @intCast(pos.v[0]);
        const y: usize = @intCast(pos.v[1]);
        _ = try self.cells.set(x, y, tile);
        switch (tile) {
            .ball => {
                if (self.paddle.v[0] > pos.v[0]) {
                    try self.computer.enqueueInput(-1);
                } else if (self.paddle.v[0] < pos.v[0]) {
                    try self.computer.enqueueInput(1);
                } else {
                    try self.computer.enqueueInput(0);
                }
            },
            .paddle => self.paddle = pos,
            else => {},
        }
    }

    pub fn count_tiles(self: Arcade, wanted: Tile) usize {
        var count: usize = 0;
        for (0..self.cells.rows()) |y| {
            for (0..self.cells.cols()) |x| {
                const tile = self.cells.get(x, y);
                if (tile != wanted) continue;
                count += 1;
            }
        }
        return count;
    }
};
