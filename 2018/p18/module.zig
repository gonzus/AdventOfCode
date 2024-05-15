const std = @import("std");
const testing = std.testing;
const Grids = @import("./util/grid.zig");
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Forest = struct {
    const StringId = StringTable.StringId;
    const Grid = Grids.DenseGrid(Kind);

    const Kind = enum(u8) {
        tree = '|',
        lumberyard = '#',
        ground = '.',

        pub fn parse(c: u8) !Kind {
            for (Kinds) |k| {
                if (@intFromEnum(k) == c) return k;
            }
            return error.InvalidKind;
        }

        pub fn format(
            v: Kind,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            try writer.print("{c}", .{@intFromEnum(v)});
        }
    };
    const Kinds = std.meta.tags(Kind);

    cur: usize,
    grid: [2]Grid,
    strtab: StringTable,
    seen: std.AutoHashMap(StringId, usize),

    pub fn init(allocator: Allocator) !Forest {
        var self = Forest{
            .cur = 0,
            .grid = undefined,
            .strtab = StringTable.init(allocator),
            .seen = std.AutoHashMap(StringId, usize).init(allocator),
        };
        for (0..2) |pos| {
            self.grid[pos] = Grid.init(allocator, .ground);
        }
        return self;
    }

    pub fn deinit(self: *Forest) void {
        self.seen.deinit();
        self.strtab.deinit();
        for (0..2) |pos| {
            self.grid[pos].deinit();
        }
    }

    pub fn addLine(self: *Forest, line: []const u8) !void {
        const y = self.grid[self.cur].rows();
        for (0..2) |pos| {
            try self.grid[pos].ensureCols(line.len);
            try self.grid[pos].ensureExtraRow();
        }
        for (line, 0..) |c, x| {
            try self.grid[self.cur].set(x, y, try Kind.parse(c));
        }
    }

    pub fn show(self: *Forest) void {
        std.debug.print("Forest on a {}x{} grid\n", .{
            self.grid[self.cur].rows(),
            self.grid[self.cur].cols(),
        });
        for (0..self.grid[self.cur].rows()) |y| {
            for (0..self.grid[self.cur].cols()) |x| {
                std.debug.print("{c}", .{self.grid[self.cur].get(x, y)});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn simulateFor(self: *Forest, minutes: usize) !usize {
        for (1..minutes + 1) |generation| {
            const previous = try self.step(generation);
            var extra: usize = std.math.maxInt(usize);
            if (previous != generation) {
                const size = generation - previous;
                const delta = minutes - generation;
                extra = delta % size;
            }
            if (extra == 0) break;
        }
        var tree_count: usize = 0;
        var lumberyard_count: usize = 0;
        for (0..self.grid[self.cur].rows()) |y| {
            for (0..self.grid[self.cur].cols()) |x| {
                const c = self.grid[self.cur].get(x, y);
                switch (c) {
                    .tree => tree_count += 1,
                    .lumberyard => lumberyard_count += 1,
                    .ground => {},
                }
            }
        }
        return tree_count * lumberyard_count;
    }

    fn step(self: *Forest, generation: usize) !usize {
        var buf: [10000]u8 = undefined;
        var len: usize = 0;
        const nxt: usize = 1 - self.cur;
        for (0..self.grid[self.cur].rows()) |y| {
            for (0..self.grid[self.cur].cols()) |x| {
                var tree_count: usize = 0;
                var lumberyard_count: usize = 0;
                var dx: isize = -1;
                while (dx <= 1) : (dx += 1) {
                    var ix: isize = @intCast(x);
                    ix += dx;
                    if (ix < 0 or ix >= self.grid[self.cur].cols()) continue;
                    var dy: isize = -1;
                    while (dy <= 1) : (dy += 1) {
                        if (dx == 0 and dy == 0) continue;
                        var iy: isize = @intCast(y);
                        iy += dy;
                        if (iy < 0 or iy >= self.grid[self.cur].rows()) continue;
                        const nx: usize = @intCast(ix);
                        const ny: usize = @intCast(iy);
                        const n = self.grid[self.cur].get(nx, ny);
                        switch (n) {
                            .tree => tree_count += 1,
                            .lumberyard => lumberyard_count += 1,
                            .ground => {},
                        }
                    }
                }

                const c = self.grid[self.cur].get(x, y);
                const n: Kind = switch (c) {
                    .ground => if (tree_count >= 3) .tree else c,
                    .tree => if (lumberyard_count >= 3) .lumberyard else c,
                    .lumberyard => if (tree_count >= 1 and lumberyard_count >= 1) .lumberyard else .ground,
                };
                try self.grid[nxt].set(x, y, n);
                buf[len] = @intFromEnum(n);
                len += 1;
            }
            buf[len] = '@';
            len += 1;
        }
        self.cur = nxt;

        const id = try self.strtab.add(buf[0..len]);
        const r = try self.seen.getOrPut(id);
        if (!r.found_existing) {
            r.value_ptr.* = generation;
        }
        return r.value_ptr.*;
    }
};

test "sample part 1" {
    const data =
        \\.#.#...|#.
        \\.....#|##|
        \\.|..|...#.
        \\..|#.....#
        \\#.#|||#|#|
        \\...#.||...
        \\.|....|...
        \\||...#|.#|
        \\|.||||..|.
        \\...#.|..|.
    ;

    var forest = try Forest.init(testing.allocator);
    defer forest.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try forest.addLine(line);
    }
    // forest.show();

    const value = try forest.simulateFor(10);
    const expected = @as(usize, 1147);
    try testing.expectEqual(expected, value);
}
