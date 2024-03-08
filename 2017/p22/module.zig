const std = @import("std");
const testing = std.testing;
const Dir = @import("./util/grid.zig").Direction;
const Pos = @import("./util/grid.zig").Pos;
const SparseGrid = @import("./util/grid.zig").SparseGrid;

const Allocator = std.mem.Allocator;

pub const Cluster = struct {
    const Grid = SparseGrid(State);

    const Turn = enum {
        none,
        left,
        right,
        reverse,

        pub fn nextDir(self: Turn, dir: Dir) Dir {
            return switch (self) {
                .none => switch (dir) {
                    .N => .N,
                    .S => .S,
                    .E => .E,
                    .W => .W,
                },
                .left => switch (dir) {
                    .N => .W,
                    .S => .E,
                    .E => .N,
                    .W => .S,
                },
                .right => switch (dir) {
                    .N => .E,
                    .S => .W,
                    .E => .S,
                    .W => .N,
                },
                .reverse => switch (dir) {
                    .N => .S,
                    .S => .N,
                    .E => .W,
                    .W => .E,
                },
            };
        }
    };

    const State = enum(u8) {
        clean = '.',
        infected = '#',
        weakened = 'W',
        flagged = 'F',

        pub fn parse(c: u8) !State {
            for (States) |s| {
                if (c == @intFromEnum(s)) return s;
            }
            return error.InvalidState;
        }

        pub fn nextTurn(self: State, complex: bool) Turn {
            if (complex) {
                return switch (self) {
                    .clean => .left,
                    .weakened => .none,
                    .infected => .right,
                    .flagged => .reverse,
                };
            } else {
                return switch (self) {
                    .infected => .right,
                    else => .left,
                };
            }
        }

        pub fn nextState(self: State, complex: bool) State {
            if (complex) {
                return switch (self) {
                    .clean => .weakened,
                    .weakened => .infected,
                    .infected => .flagged,
                    .flagged => .clean,
                };
            } else {
                return switch (self) {
                    .infected => .clean,
                    else => .infected,
                };
            }
        }
    };
    const States = std.meta.tags(State);

    complex: bool,
    grid: Grid,
    pos: Pos,
    dir: Dir,

    pub fn init(allocator: Allocator, complex: bool) Cluster {
        return .{
            .complex = complex,
            .grid = Grid.init(allocator, .clean),
            .pos = undefined,
            .dir = .N,
        };
    }

    pub fn deinit(self: *Cluster) void {
        self.grid.deinit();
    }

    pub fn addLine(self: *Cluster, line: []const u8) !void {
        try self.grid.ensureCols(line.len);
        try self.grid.ensureExtraRow();
        const y = self.grid.rows();
        for (line, 0..) |c, x| {
            const pos = Pos.initFromUnsigned(x, y);
            try self.grid.set(pos, try State.parse(c));
        }
        self.pos = Pos.initFromUnsigned(self.grid.cols() / 2, self.grid.rows() / 2);
    }

    pub fn show(self: Cluster) void {
        std.debug.print("Cluster {}x{}, pos {}, dir {}\n", .{
            self.grid.rows(),
            self.grid.cols(),
            self.pos,
            self.dir,
        });
        for (0..self.grid.rows()) |y| {
            for (0..self.grid.cols()) |x| {
                const pos = Pos.initFromUnsigned(x, y);
                std.debug.print("{c}", .{@intFromEnum(self.grid.get(pos))});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn runBursts(self: *Cluster, bursts: usize) !usize {
        var count: usize = 0;
        for (0..bursts) |_| {
            const current = self.grid.get(self.pos);
            const turn = current.nextTurn(self.complex);
            const state = current.nextState(self.complex);
            try self.grid.set(self.pos, state);
            self.dir = turn.nextDir(self.dir);
            try self.pos.move(self.dir);
            if (state != .infected) continue;
            count += 1;
        }
        return count;
    }
};

test "sample part 1" {
    const data =
        \\..#
        \\#..
        \\...
    ;

    var cluster = Cluster.init(std.testing.allocator, false);
    defer cluster.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    const infections = try cluster.runBursts(10000);
    const expected = @as(usize, 5587);
    try testing.expectEqual(expected, infections);
}

test "sample part 2 part A" {
    const data =
        \\..#
        \\#..
        \\...
    ;

    var cluster = Cluster.init(std.testing.allocator, true);
    defer cluster.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    const infections = try cluster.runBursts(100);
    const expected = @as(usize, 26);
    try testing.expectEqual(expected, infections);
}

test "sample part 2 part B" {
    const data =
        \\..#
        \\#..
        \\...
    ;

    var cluster = Cluster.init(std.testing.allocator, true);
    defer cluster.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cluster.addLine(line);
    }
    // cluster.show();

    const infections = try cluster.runBursts(10000000);
    const expected = @as(usize, 2511944);
    try testing.expectEqual(expected, infections);
}
