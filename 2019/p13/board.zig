const std = @import("std");
const assert = std.debug.assert;
const Computer = @import("./computer.zig").Computer;

pub const Pos = struct {
    x: usize,
    y: usize,

    pub fn encode(self: Pos) usize {
        return self.x * 10000 + self.y;
    }
};

pub const Board = struct {
    cells: std.AutoHashMap(usize, Tile),
    computer: Computer,
    nx: i64,
    ny: i64,
    pmin: Pos,
    pmax: Pos,
    finished: bool,
    state: usize,
    bpos: Pos,
    ppos: Pos,
    score: usize,
    hacked: bool,

    pub const Tile = enum(u8) {
        Empty = 0,
        Wall = 1,
        Block = 2,
        Paddle = 3,
        Ball = 4,
    };

    pub fn init(hacked: bool) Board {
        var self = Board{
            .cells = std.AutoHashMap(usize, Tile).init(std.heap.direct_allocator),
            .computer = Computer.init(true),
            .nx = undefined,
            .ny = undefined,
            .pmin = Pos{ .x = 999999, .y = 999999 },
            .pmax = Pos{ .x = 0, .y = 0 },
            .bpos = Pos{ .x = 0, .y = 0 },
            .ppos = Pos{ .x = 0, .y = 0 },
            .finished = false,
            .state = 0,
            .score = 0,
            .hacked = hacked,
        };
        return self;
    }

    pub fn deinit(self: *Board) void {
        self.computer.deinit();
        self.cells.deinit();
    }

    pub fn parse(self: *Board, str: []const u8) void {
        self.computer.parse(str, self.hacked);
    }

    pub fn run(self: *Board) void {
        while (true) {
            self.computer.run();
            while (true) {
                const output = self.computer.getOutput();
                if (output == null) break;
                _ = self.process_output(output.?);
            }
            if (self.hacked) self.show();
            if (self.computer.halted) {
                std.debug.warn("HALT computer\n");
                break;
            }
        }
    }

    pub fn process_output(self: *Board, output: i64) bool {
        switch (self.state) {
            0 => {
                self.nx = output;
                self.state = 1;
            },
            1 => {
                self.ny = output;
                self.state = 2;
            },
            2 => {
                if (self.nx == -1 and self.ny == 0) {
                    // std.debug.warn("SCORE: {}\n", output);
                    self.score = @intCast(usize, output);
                } else {
                    const p = Pos{ .x = @intCast(usize, self.nx), .y = @intCast(usize, self.ny) };
                    var t: Tile = @intToEnum(Tile, @intCast(u8, output));
                    self.put_tile(p, t);
                    // std.debug.warn("TILE: {} {} {}\n", p.x, p.y, t);
                }
                self.state = 0;
            },
            else => unreachable,
        }
        return true;
    }

    pub fn get_tile(self: Board, pos: Pos) []const u8 {
        const label = pos.encode();
        const got = self.cells.get(label);
        var c: []const u8 = " ";
        if (got == null) return c;
        switch (got.?.value) {
            Tile.Empty => c = " ",
            Tile.Wall => c = "X",
            Tile.Block => c = "#",
            Tile.Paddle => c = "-",
            Tile.Ball => c = "O",
        }
        return c;
    }

    pub fn show(self: Board) void {
        const stdout = std.io.getStdOut() catch unreachable;
        const out = &stdout.outStream().stream;
        const escape: u8 = 0o33;
        out.print("{c}[2J{c}[H", escape, escape) catch unreachable;
        var y: usize = self.pmin.y;
        while (y <= self.pmax.y) : (y += 1) {
            var x: usize = self.pmin.x;
            while (x <= self.pmax.x) : (x += 1) {
                const pos = Pos{ .x = x, .y = y };
                const tile = self.get_tile(pos);
                out.print("{}", tile) catch unreachable;
            }
            out.print("\n") catch unreachable;
        }
        out.print("SCORE: {}\n", self.score) catch unreachable;
    }

    pub fn put_tile(self: *Board, pos: Pos, t: Tile) void {
        const label = pos.encode();
        _ = self.cells.put(label, t) catch unreachable;
        if (t == Tile.Block) {}
        if (t == Tile.Ball) {
            self.bpos = pos;
            if (self.ppos.x > self.bpos.x) {
                // std.debug.warn("MOVE left {} {}\n", self.ppos.x, self.bpos.x);
                self.computer.enqueueInput(-1);
            } else if (self.ppos.x < self.bpos.x) {
                // std.debug.warn("MOVE right {} {}\n", self.ppos.x, self.bpos.x);
                self.computer.enqueueInput(1);
            } else {
                // std.debug.warn("MOVE none {} {}\n", self.ppos.x, self.bpos.x);
                self.computer.enqueueInput(0);
            }
        }
        if (t == Tile.Paddle) {
            self.ppos = pos;
        }
        if (t == Tile.Block) {}
        if (self.pmin.x > pos.x) self.pmin.x = pos.x;
        if (self.pmin.y > pos.y) self.pmin.y = pos.y;
        if (self.pmax.x < pos.x) self.pmax.x = pos.x;
        if (self.pmax.y < pos.y) self.pmax.y = pos.y;
    }

    pub fn count_tiles(self: Board, t: Tile) usize {
        // std.debug.warn("MIN {} {} - MAX {} {}\n", self.pmin.x, self.pmin.y, self.pmax.x, self.pmax.y);
        // std.debug.warn("BALL {} {}\n", self.bpos.x, self.bpos.y);
        // std.debug.warn("PADDLE {} {}\n", self.ppos.x, self.ppos.y);
        var it = self.cells.iterator();
        var count: usize = 0;
        while (it.next()) |entry| {
            if (entry.value != t) continue;
            count += 1;
        }
        return count;
    }
};

test "without blocks" {
    // std.debug.warn("\n");
    var board = Board.init(false);
    defer board.deinit();

    const data = "1,2,2,6,5,4";
    var it = std.mem.separate(data, ",");
    while (it.next()) |what| {
        const output = std.fmt.parseInt(i64, what, 10) catch unreachable;
        const more = board.process_output(output);
        if (!more) break;
    }
    const count = board.count_tiles(Board.Tile.Block);
    assert(count == 1);
}

test "with blocks" {
    // std.debug.warn("\n");
    var board = Board.init(false);
    defer board.deinit();

    const data = "1,2,3,6,5,4";
    var it = std.mem.separate(data, ",");
    while (it.next()) |what| {
        const output = std.fmt.parseInt(i64, what, 10) catch unreachable;
        const more = board.process_output(output);
        if (!more) break;
    }
    const count = board.count_tiles(Board.Tile.Block);
    assert(count == 0);
}
