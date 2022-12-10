const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

const RELEVANT_CYCLE_FIRST = 20;
const RELEVANT_CYCLE_DELTA = 40;

const BITMAP_WIDTH = 40;
const BITMAP_HEIGHT = 6;
const BITMAP_SIZE = BITMAP_WIDTH * BITMAP_HEIGHT;

const InstrTag = enum(u8) {
    AddX,
    NoOp,
};

const Instr = union(InstrTag) {
    AddX: i32,
    NoOp: void,

    pub fn parse(line: []const u8) !Instr {
        var it = std.mem.tokenize(u8, line, " ");
        const instr = it.next().?;
        if (std.mem.eql(u8, instr, "addx")) {
            return Instr{.AddX = try std.fmt.parseInt(i32, it.next().?, 10) };
        }
        return Instr{.NoOp = {}};
    }
};

pub const Cpu = struct {
    instr: std.ArrayList(Instr),
    X: i32,
    pc: usize,
    cycle: usize,
    pending: Instr,
    next_relevant_cycle: usize,
    bitmap: [BITMAP_SIZE]u8,

    pub fn init(allocator: Allocator) Cpu {
        var self = Cpu{
            .instr = std.ArrayList(Instr).init(allocator),
            .X = 0,
            .pc = 0,
            .cycle = 0,
            .pending = .NoOp,
            .next_relevant_cycle = 0,
            .bitmap = undefined,
        };
        return self;
    }

    pub fn deinit(self: *Cpu) void {
        self.instr.deinit();
    }

    pub fn add_line(self: *Cpu, line: []const u8) !void {
        try self.instr.append(try Instr.parse(line));
    }

    pub fn reset(self: *Cpu) void {
        self.X = 1;
        self.pc = 0;
        self.cycle = 0;
        self.pending = .NoOp;
        self.next_relevant_cycle = RELEVANT_CYCLE_FIRST;
        self.bitmap = [_]u8{'.'} ** BITMAP_SIZE;
    }

    pub fn done(self: Cpu) bool {
        return (self.pc >= self.instr.items.len and self.pending == .NoOp);
    }

    pub fn run(self: *Cpu) i32 {
        self.reset();
        var total_strength: i32 = 0;
        var scan_pos: usize = 0;
        while (self.pc < self.instr.items.len) {
            const sprite_pos = scan_pos % BITMAP_WIDTH;
            if (sprite_pos >= self.X - 1 and sprite_pos <= self.X + 1) {
                self.bitmap[scan_pos] = '#';
            }

            self.cycle += 1;
            scan_pos += 1;
            scan_pos %= BITMAP_SIZE;

            if (self.cycle == self.next_relevant_cycle) {
                total_strength += @intCast(i32, self.cycle) * self.X;
                self.next_relevant_cycle += RELEVANT_CYCLE_DELTA;
            }

            switch (self.pending) {
                .AddX => |delta| {
                    self.X += delta;
                    self.pending = .NoOp;
                    self.pc += 1;
                    continue;
                },
                else => {},
            }

            const instr = self.instr.items[self.pc];
            switch (instr) {
                .NoOp => self.pc += 1,
                .AddX => self.pending = instr,
            }

            if (self.done()) break;
        }
        return total_strength;
    }

    pub fn render_image(self: Cpu) void {
        var scan_pos: usize = 0;
        while (scan_pos < BITMAP_SIZE) : (scan_pos += 1) {
            if (scan_pos % BITMAP_WIDTH == 0) {
                std.debug.print("\n", .{});
            }
            var c: u8 = self.bitmap[scan_pos];
            switch (c) {
                '.' => std.debug.print("{s}", .{" "}),
                '#' => std.debug.print("{s}", .{"█"}),
                else => unreachable,
            }
        }
        std.debug.print("\n", .{});
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\noop
        \\addx 3
        \\addx -5
    ;

    var cpu = Cpu.init(std.testing.allocator);
    defer cpu.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cpu.add_line(line);
    }

    _ = cpu.run();
    try testing.expect(cpu.X == -1);
}

test "sample part 2" {
    const data: []const u8 =
        \\addx 15
        \\addx -11
        \\addx 6
        \\addx -3
        \\addx 5
        \\addx -1
        \\addx -8
        \\addx 13
        \\addx 4
        \\noop
        \\addx -1
        \\addx 5
        \\addx -1
        \\addx 5
        \\addx -1
        \\addx 5
        \\addx -1
        \\addx 5
        \\addx -1
        \\addx -35
        \\addx 1
        \\addx 24
        \\addx -19
        \\addx 1
        \\addx 16
        \\addx -11
        \\noop
        \\noop
        \\addx 21
        \\addx -15
        \\noop
        \\noop
        \\addx -3
        \\addx 9
        \\addx 1
        \\addx -3
        \\addx 8
        \\addx 1
        \\addx 5
        \\noop
        \\noop
        \\noop
        \\noop
        \\noop
        \\addx -36
        \\noop
        \\addx 1
        \\addx 7
        \\noop
        \\noop
        \\noop
        \\addx 2
        \\addx 6
        \\noop
        \\noop
        \\noop
        \\noop
        \\noop
        \\addx 1
        \\noop
        \\noop
        \\addx 7
        \\addx 1
        \\noop
        \\addx -13
        \\addx 13
        \\addx 7
        \\noop
        \\addx 1
        \\addx -33
        \\noop
        \\noop
        \\noop
        \\addx 2
        \\noop
        \\noop
        \\noop
        \\addx 8
        \\noop
        \\addx -1
        \\addx 2
        \\addx 1
        \\noop
        \\addx 17
        \\addx -9
        \\addx 1
        \\addx 1
        \\addx -3
        \\addx 11
        \\noop
        \\noop
        \\addx 1
        \\noop
        \\addx 1
        \\noop
        \\noop
        \\addx -13
        \\addx -19
        \\addx 1
        \\addx 3
        \\addx 26
        \\addx -30
        \\addx 12
        \\addx -1
        \\addx 3
        \\addx 1
        \\noop
        \\noop
        \\noop
        \\addx -9
        \\addx 18
        \\addx 1
        \\addx 2
        \\noop
        \\noop
        \\addx 9
        \\noop
        \\noop
        \\noop
        \\addx -1
        \\addx 2
        \\addx -37
        \\addx 1
        \\addx 3
        \\noop
        \\addx 15
        \\addx -21
        \\addx 22
        \\addx -6
        \\addx 1
        \\noop
        \\addx 2
        \\addx 1
        \\noop
        \\addx -10
        \\noop
        \\noop
        \\addx 20
        \\addx 1
        \\addx 2
        \\addx 2
        \\addx -6
        \\addx -11
        \\noop
        \\noop
        \\noop
    ;

    var cpu = Cpu.init(std.testing.allocator);
    defer cpu.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cpu.add_line(line);
    }

    const strength = cpu.run();
    try testing.expect(strength == 13140);

    const expected: []const u8 =
        \\##..##..##..##..##..##..##..##..##..##..
        \\###...###...###...###...###...###...###.
        \\####....####....####....####....####....
        \\#####.....#####.....#####.....#####.....
        \\######......######......######......####
        \\#######.......#######.......#######.....
    ;

    var row: usize = 0;
    var pos_got: usize = 0;
    var pos_want: usize = 0;
    while (row < BITMAP_HEIGHT) : (row += 1) {
        const got = cpu.bitmap[pos_got..pos_got+BITMAP_WIDTH];
        const want = expected[pos_want..pos_want+BITMAP_WIDTH];
        pos_got += BITMAP_WIDTH;
        pos_want += BITMAP_WIDTH + 1; // skip newline at end
        try testing.expect(std.mem.eql(u8, got, want));
    }
}
