const std = @import("std");
const testing = std.testing;
const DoubleEndedQueue = @import("./util/queue.zig").DoubleEndedQueue;
const Math = @import("./util/math.zig").Math;
const UtilGrid = @import("./util/grid.zig");
const StringTable = @import("./util/strtab.zig").StringTable;

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
        try self.data.appendSlice(self.code.items);
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
        return @intCast(self.data.items[self.pc]);
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

pub const Scaffold = struct {
    const Pos = UtilGrid.Pos;
    const Grid = UtilGrid.SparseGrid(Tile);
    const Score = std.AutoHashMap(Pos, usize);
    const StringId = StringTable.StringId;
    const String = std.ArrayList(u8);
    const OFFSET = 10_000;
    const SEGMENTS = 3;
    const MAX_SEGMENT_LENGTH = 20;
    const SLEEP_TIME = 10_000_000; // 10 ms
    const SEP_INSTRUCTION = ':';
    const SEP_INPUT = ',';
    const OVERSTRIKE = '@';
    const NEWLINE = '#';

    pub const Turn = enum(u8) {
        L = 'L',
        R = 'R',
    };

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

        pub fn turn(c: Dir, w: Dir) ?Turn {
            var t: ?Turn = null;
            switch (c) {
                .N => {
                    switch (w) {
                        .N => t = null,
                        .S => t = null,
                        .W => t = .L,
                        .E => t = .R,
                    }
                },
                .S => {
                    switch (w) {
                        .N => t = null,
                        .S => t = null,
                        .W => t = .R,
                        .E => t = .L,
                    }
                },
                .W => {
                    switch (w) {
                        .N => t = .R,
                        .S => t = .L,
                        .W => t = null,
                        .E => t = null,
                    }
                },
                .E => {
                    switch (w) {
                        .N => t = .L,
                        .S => t = .R,
                        .W => t = null,
                        .E => t = null,
                    }
                },
            }
            return t;
        }

        pub fn parse(c: u8) !Dir {
            for (Dirs) |d| {
                if (@intFromEnum(d) == c) return d;
            }
            return error.InvalidDir;
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

    pub const Tile = enum(u8) {
        empty = '.',
        scaffold = '#',
        robot = '*',

        pub fn parse(c: u8) !Tile {
            for (Tiles) |t| {
                if (@intFromEnum(t) == c) return t;
            }
            return error.InvalidTile;
        }

        pub fn format(
            tile: Tile,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("{c}", .{@intFromEnum(tile)});
        }
    };
    const Tiles = std.meta.tags(Tile);

    allocator: Allocator,
    strtab: StringTable,
    computer: Computer,
    grid: Grid,
    route: String,
    program: String,
    pos_current: Pos,
    robot_dir: Dir,
    show_output: bool,
    show_prompts: bool,

    pub fn init(allocator: Allocator) Scaffold {
        return .{
            .allocator = allocator,
            .strtab = StringTable.init(allocator),
            .computer = Computer.init(allocator),
            .grid = Grid.init(allocator, .empty),
            .route = String.init(allocator),
            .program = String.init(allocator),
            .pos_current = Pos.init(OFFSET / 2, OFFSET / 2),
            .robot_dir = undefined,
            .show_output = false, // change to true to see computer output
            .show_prompts = false, // change to true to see computer prompts
        };
    }

    pub fn deinit(self: *Scaffold) void {
        self.program.deinit();
        self.route.deinit();
        self.grid.deinit();
        self.computer.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Scaffold, line: []const u8) !void {
        try self.computer.addLine(line);
    }

    pub fn getSumOfAlignmentParameters(self: *Scaffold) !usize {
        try self.computer.resetComputer();
        try self.runAndDiscoverMap();

        self.route.clearRetainingCapacity();
        return try self.walkAroundMap();
    }

    pub fn getTotalDustCollected(self: *Scaffold) !usize {
        try self.computer.resetComputer();
        self.computer.data.items[0] = 2;
        try self.runAndDiscoverMap();

        self.route.clearRetainingCapacity();
        _ = try self.walkAroundMap();

        try self.splitAndBuildProgram();
        if (self.program.items.len <= 0) return error.InvalidProgram;

        return try self.runGeneratedProgram();
    }

    fn runAndDiscoverMap(self: *Scaffold) !void {
        var y: usize = 0;
        var x: usize = 0;
        main: while (true) {
            try self.computer.runWithoutInput();
            while (true) {
                if (self.computer.dequeueOutput()) |output| {
                    var c: u8 = @intCast(output);
                    switch (c) {
                        '\n' => {
                            if (x == 0) break :main;
                            y += 1;
                            x = 0;
                            continue;
                        },
                        '^' => {
                            self.robot_dir = .N;
                            c = '*';
                        },
                        'v' => {
                            self.robot_dir = .S;
                            c = '*';
                        },
                        '<' => {
                            self.robot_dir = .W;
                            c = '*';
                        },
                        '>' => {
                            self.robot_dir = .E;
                            c = '*';
                        },
                        'X' => {
                            c = '*';
                        },
                        else => {},
                    }
                    const t = try Tile.parse(c);
                    const p = Pos.init(@intCast(x + OFFSET / 2), @intCast(y + OFFSET / 2));
                    try self.grid.set(p, t);
                    if (t == .robot) {
                        self.pos_current = p;
                    }
                    x += 1;
                } else {
                    break;
                }
                if (self.computer.halted) break;
            }
        }
    }

    fn walkAroundMap(self: *Scaffold) !usize {
        var sum: usize = 0;
        var seen = std.AutoHashMap(Pos, void).init(self.allocator);
        defer seen.deinit();
        var pos: Pos = self.pos_current;
        var dir: Dir = undefined;
        var rev: ?Dir = null;
        while (true) {
            var found: bool = false;
            for (Dirs) |d| {
                if (rev != null and d == rev.?) continue;
                const nxt = Dir.move(pos, d);
                if (self.grid.get(nxt) == .scaffold) {
                    found = true;
                    pos = nxt;
                    dir = d;
                    rev = Dir.reverse(dir);
                    break;
                }
            }
            if (!found) break;
            const turn = Dir.turn(self.robot_dir, dir);
            if (turn != null) {
                try self.route.append(@intFromEnum(turn.?));
                try self.route.append(SEP_INPUT);
                self.robot_dir = dir;
            }
            {
                const r = try seen.getOrPut(pos);
                if (r.found_existing) {
                    const alignment: usize = @intCast((pos.x - OFFSET / 2) * (pos.y - OFFSET / 2));
                    sum += alignment;
                }
            }
            var steps: usize = 1;
            while (true) : (steps += 1) {
                const nxt = Dir.move(pos, dir);
                if (self.grid.get(nxt) != .scaffold) {
                    break;
                }
                pos = nxt;
                const r = try seen.getOrPut(pos);
                if (r.found_existing) {
                    const alignment: usize = @intCast((pos.x - OFFSET / 2) * (pos.y - OFFSET / 2));
                    sum += alignment;
                }
            }
            var buf: [30]u8 = undefined;
            const num = try std.fmt.bufPrint(&buf, "{d}", .{steps});
            try self.route.appendSlice(num);
            try self.route.append(SEP_INPUT);
        }
        return sum;
    }

    fn splitAndBuildProgram(self: *Scaffold) !void {
        var buf = String.init(self.allocator);
        defer buf.deinit();
        var digits = false;
        for (self.route.items) |r| {
            if (r >= '0' and r <= '9') {
                if (!digits) {
                    if (buf.items.len > 0) try buf.append(SEP_INPUT);
                }
                digits = true;
                try buf.append(r);
                continue;
            }
            if (r == 'L' or r == 'R') {
                digits = false;
                if (buf.items.len > 0) try buf.append(SEP_INSTRUCTION);
                try buf.append(r);
                continue;
            }
        }

        var colons = std.ArrayList(usize).init(self.allocator);
        defer colons.deinit();
        try colons.append(0);
        for (0..buf.items.len) |p| {
            if (buf.items[p] != SEP_INSTRUCTION) continue;
            try colons.append(p + 1);
        }
        try colons.append(buf.items.len + 1);
        var words: [SEGMENTS][]const u8 = undefined;
        var copy = String.init(self.allocator);
        defer copy.deinit();
        for (0..colons.items.len) |b0| {
            for (b0 + 1..colons.items.len) |e0| {
                const l0 = colons.items[e0] - colons.items[b0] - 1;
                if (l0 > MAX_SEGMENT_LENGTH) continue;
                words[0] = buf.items[colons.items[b0] .. colons.items[b0] + l0];
                for (e0..colons.items.len) |b1| {
                    for (b1 + 1..colons.items.len) |e1| {
                        const l1 = colons.items[e1] - colons.items[b1] - 1;
                        if (l1 > MAX_SEGMENT_LENGTH) continue;
                        words[1] = buf.items[colons.items[b1] .. colons.items[b1] + l1];
                        for (e1..colons.items.len) |b2| {
                            for (b2 + 1..colons.items.len) |e2| {
                                const l2 = colons.items[e2] - colons.items[b2] - 1;
                                if (l2 > MAX_SEGMENT_LENGTH) continue;
                                words[2] = buf.items[colons.items[b2] .. colons.items[b2] + l2];

                                copy.clearRetainingCapacity();
                                if (!try isFullyCovered(&copy, buf.items, &words)) continue;

                                try self.buildProgram(buf.items, &words);
                                break;
                            }
                        }
                    }
                }
            }
        }
    }

    fn runGeneratedProgram(self: *Scaffold) !usize {
        var it = std.mem.splitScalar(u8, self.program.items, NEWLINE);
        while (it.next()) |line| {
            try self.provideComputerInput(line);
        }

        // Answer to "Continuous video feed?"
        // pass "y" to see robot moving
        try self.provideComputerInput(if (self.show_output) "y" else "n");

        var dust: usize = 0;
        var newlines: usize = 0;
        while (true) {
            const result = self.computer.dequeueOutput();
            if (result == null) break;
            const value = result.?;
            if (value >= 0 and value < 256) {
                if (value == '\n') {
                    newlines += 1;
                } else {
                    newlines = 0;
                }
                if (self.show_output) {
                    if (newlines > 1) {
                        std.time.sleep(SLEEP_TIME);
                        const escape: u8 = 0o33;
                        std.debug.print("{c}[2J{c}[H", .{ escape, escape });
                    }
                    const c = @as(u8, @intCast(value));
                    std.debug.print("{c}", .{c});
                }
            } else {
                dust = @intCast(value);
            }
        }
        return dust;
    }

    fn provideComputerInput(self: *Scaffold, line: []const u8) !void {
        if (self.show_prompts) {
            std.debug.print("> ", .{});
        }
        while (true) {
            if (self.computer.dequeueOutput()) |output| {
                const c: u8 = @intCast(output);
                if (self.show_prompts) {
                    std.debug.print("{c}", .{c});
                }
                if (c == '\n') break;
            } else {
                return error.InvalidOutput;
            }
        }
        if (self.show_prompts) {
            std.debug.print("< {s}\n", .{line});
        }
        for (0..line.len) |p| {
            var c = line[p];
            if (c == NEWLINE) break;
            if (c == SEP_INSTRUCTION) c = SEP_INPUT;
            try self.computer.enqueueInput(@intCast(c));
        }
        try self.computer.enqueueInput('\n');
        try self.computer.runWithoutInput();
    }

    fn isFullyCovered(copy: *String, orig: []const u8, words: [][]const u8) !bool {
        copy.clearRetainingCapacity();
        try copy.appendSlice(orig);
        for (0..SEGMENTS) |s| {
            const text = words[s];
            const top = orig.len - text.len + 1;
            for (0..top) |p| {
                if (std.mem.eql(u8, copy.items[p .. p + text.len], text)) {
                    for (0..text.len) |q| {
                        copy.items[p + q] = OVERSTRIKE;
                    }
                }
            }
        }
        for (0..orig.len) |p| {
            if (copy.items[p] == OVERSTRIKE) continue;
            if (copy.items[p] == SEP_INSTRUCTION) continue;
            return false;
        }
        return true;
    }

    fn buildProgram(self: *Scaffold, orig: []const u8, words: [][]const u8) !void {
        self.program.clearRetainingCapacity();
        var pos: usize = 0;
        while (pos < orig.len) {
            for (0..SEGMENTS) |s| {
                const part = words[s];
                if (std.mem.eql(u8, part, orig[pos .. pos + part.len])) {
                    if (self.program.items.len > 0) {
                        try self.program.append(SEP_INPUT);
                    }
                    try self.program.append(@intCast(s + 'A'));
                    pos += part.len + 1;
                    break;
                }
            }
        }
        for (0..SEGMENTS) |s| {
            const part = words[s];
            try self.program.append(NEWLINE);
            try self.program.appendSlice(part);
        }
    }
};
