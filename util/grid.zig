const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Direction = enum {
    N,
    W,
    S,
    E,

    pub fn parse(c: u8) !Direction {
        const dir: Direction = switch (c) {
            'N' => .N,
            'S' => .S,
            'E' => .E,
            'W' => .W,
            else => return error.InvalidDirection,
        };
        return dir;
    }

    pub fn format(
        dir: Direction,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = try writer.print("({s})", .{@tagName(dir)});
    }
};

pub const Pos = struct {
    x: isize,
    y: isize,

    pub fn init(x: isize, y: isize) Pos {
        const self = Pos{ .x = x, .y = y };
        return self;
    }

    pub fn initFromUnsigned(x: usize, y: usize) Pos {
        return Pos.init(@intCast(x), @intCast(y));
    }

    pub fn equal(self: Pos, other: Pos) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn cmp(_: void, l: Pos, r: Pos) std.math.Order {
        if (l.x < r.x) return std.math.Order.lt;
        if (l.x > r.x) return std.math.Order.gt;
        if (l.y < r.y) return std.math.Order.lt;
        if (l.y > r.y) return std.math.Order.gt;
        return std.math.Order.eq;
    }

    pub fn manhattanDist(self: Pos, other: Pos) usize {
        const dx: usize = @intCast(if (self.x < other.x) other.x - self.x else self.x - other.x);
        const dy: usize = @intCast(if (self.y < other.y) other.y - self.y else self.y - other.y);
        return dx + dy;
    }

    pub fn euclideanDistSq(self: Pos, other: Pos) usize {
        const dx: usize = @intCast(if (self.x < other.x) other.x - self.x else self.x - other.x);
        const dy: usize = @intCast(if (self.y < other.y) other.y - self.y else self.y - other.y);
        return dx * dx + dy * dy;
    }

    pub fn move(self: *Pos, dir: Direction) !void {
        switch (dir) {
            .N => self.y -= 1,
            .S => self.y += 1,
            .E => self.x += 1,
            .W => self.x -= 1,
        }
    }

    pub fn format(
        pos: Pos,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = try writer.print("({d},{d})", .{ pos.x, pos.y });
    }
};

pub fn DenseGrid(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn init(allocator: Allocator, default: T) Self {
            const self = Self{
                .allocator = allocator,
                .default = default,
                .data = &.{},
                .row_cap = 0,
                .row_len = 0,
                .col_cap = 0,
                .col_len = 0,
            };
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.data);
        }

        pub fn clone(self: Self) !Self {
            var copy = Self.init(self.allocator, self.default);
            try copy.ensureCols(self.cols());
            for (0..self.rows()) |y| {
                try copy.ensureExtraRow();
                for (0..self.cols()) |x| {
                    try copy.set(x, y, self.get(x, y));
                }
            }
            return copy;
        }

        fn ensureSize(self: *Self, new_rows: usize, new_cols: usize) !void {
            if (self.row_cap >= new_rows and self.col_cap >= new_cols) return;
            const old_size = self.row_cap * self.col_cap;
            const new_size = new_rows * new_cols;
            const new_data = try self.allocator.realloc(self.data, new_size);
            for (old_size..new_size) |p| {
                new_data[p] = self.default;
            }
            self.data = new_data;
            self.row_cap = new_rows;
            self.col_cap = new_cols;
        }

        pub fn ensureCols(self: *Self, new_cols: usize) !void {
            const new_rows = @max(self.row_cap, new_cols); // estimate
            try self.ensureSize(new_rows, new_cols);
        }

        pub fn ensureRows(self: *Self, new_rows: usize) !void {
            const new_cols = @max(new_rows, self.col_cap); // estimate
            try self.ensureSize(new_rows, new_cols);
        }

        pub fn ensureExtraRow(self: *Self) !void {
            const new_rows = self.row_len + 1;
            const new_cols = self.col_len;
            try self.ensureSize(new_rows, new_cols);
        }

        pub fn clear(self: *Self) void {
            self.row_len = 0;
            self.col_len = 0;
            for (0..self.row_cap * self.col_cap) |p| {
                self.data[p] = self.default;
            }
        }

        pub fn validPos(self: Self, x: isize, y: isize) bool {
            if (x < 0 or x >= self.col_len) return false;
            if (y < 0 or y >= self.row_len) return false;
            return true;
        }

        pub fn rows(self: Self) usize {
            return self.row_len;
        }

        pub fn cols(self: Self) usize {
            return self.col_len;
        }

        pub fn get(self: Self, x: usize, y: usize) T {
            if (x < 0 or x >= self.col_len or y < 0 or y >= self.row_len)
                return self.default;
            const pos = self.col_cap * y + x;
            return self.data[pos];
        }

        pub fn getSigned(self: Self, x: isize, y: isize) T {
            return self.get(@intCast(x), @intCast(y));
        }

        pub fn set(self: *Self, x: usize, y: usize, val: T) !void {
            try self.ensureCols(x + 1);
            try self.ensureRows(y + 1);
            if (self.col_len <= x) self.col_len = x + 1;
            if (self.row_len <= y) self.row_len = y + 1;
            const pos = self.col_cap * y + x;
            self.data[pos] = val;
        }

        pub fn setSigned(self: *Self, x: isize, y: isize, val: T) !void {
            return self.set(@intCast(x), @intCast(y), val);
        }

        allocator: Allocator,
        default: T,
        data: []T,
        row_cap: usize,
        row_len: usize,
        col_cap: usize,
        col_len: usize,
    };
}

pub fn SparseGrid(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn init(allocator: Allocator, default: T) Self {
            var self = Self{
                .allocator = allocator,
                .default = default,
                .data = std.AutoHashMap(Pos, T).init(allocator),
                .min = undefined,
                .max = undefined,
            };
            self.clear();
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
        }

        pub fn ensureCols(_: *Self, _: usize) !void {}

        pub fn ensureExtraRow(_: *Self) !void {}

        pub fn clear(self: *Self) void {
            self.data.clearRetainingCapacity();
            self.min = Pos.init(std.math.maxInt(isize), std.math.maxInt(isize));
            self.max = Pos.init(std.math.minInt(isize), std.math.minInt(isize));
        }

        pub fn validPos(self: Self, x: isize, y: isize) bool {
            if (x < self.min.x or x > self.max.x) return false;
            if (y < self.min.y or y > self.max.y) return false;
            return true;
        }

        pub fn rows(self: Self) usize {
            if (self.data.count() == 0) return 0;
            return @intCast(self.max.y - self.min.y + 1);
        }

        pub fn cols(self: Self) usize {
            if (self.data.count() == 0) return 0;
            return @intCast(self.max.x - self.min.x + 1);
        }

        pub fn get(self: Self, pos: Pos) T {
            const value = self.data.get(pos) orelse self.default;
            return value;
        }

        pub fn set(self: *Self, pos: Pos, val: T) !void {
            const entry = try self.data.getOrPut(pos);
            entry.value_ptr.* = val;
            if (entry.found_existing) return;

            if (self.min.x > pos.x) self.min.x = pos.x;
            if (self.max.x < pos.x) self.max.x = pos.x;
            if (self.min.y > pos.y) self.min.y = pos.y;
            if (self.max.y < pos.y) self.max.y = pos.y;
        }

        allocator: Allocator,
        default: T,
        data: std.AutoHashMap(Pos, T),
        min: Pos,
        max: Pos,
    };
}

test "Direction" {
    try testing.expectEqual(Direction.parse('N'), .N);
    try testing.expectEqual(Direction.parse('S'), .S);
    try testing.expectEqual(Direction.parse('E'), .E);
    try testing.expectEqual(Direction.parse('W'), .W);
}

test "Pos" {
    const p1 = Pos.init(3, 9);
    const p2 = Pos.init(5, 4);
    try testing.expect(p1.equal(p1));
    try testing.expect(p2.equal(p2));
    try testing.expect(!p1.equal(p2));
    try testing.expect(!p2.equal(p1));
    try testing.expectEqual(p1.manhattanDist(p2), 7);
    try testing.expectEqual(p1.euclideanDistSq(p2), 29);
    try testing.expectEqual(Pos.cmp({}, p1, p2), std.math.Order.lt);
    try testing.expectEqual(Pos.cmp({}, p2, p1), std.math.Order.gt);
    try testing.expectEqual(Pos.cmp({}, p1, p1), std.math.Order.eq);
    try testing.expectEqual(Pos.cmp({}, p2, p2), std.math.Order.eq);
}

test "DenseGrid" {
    const default = '*';
    const treasure = 'X';
    var grid = DenseGrid(u8).init(testing.allocator, default);
    defer grid.deinit();
    try testing.expectEqual(grid.rows(), 0);
    try testing.expectEqual(grid.cols(), 0);

    try grid.ensureCols(3);
    try testing.expectEqual(grid.rows(), 0);
    try testing.expectEqual(grid.cols(), 0);
    try testing.expectEqual(grid.get(1, 2), default);
    try grid.set(1, 2, treasure);
    try testing.expectEqual(grid.get(1, 2), treasure);
    try testing.expectEqual(grid.rows(), 3);
    try testing.expectEqual(grid.cols(), 2);
}

test "SparseGrid" {
    const default = '*';
    const treasure = 'X';
    var grid = SparseGrid(u8).init(testing.allocator, default);
    defer grid.deinit();
    try testing.expectEqual(grid.rows(), 0);
    try testing.expectEqual(grid.cols(), 0);

    try grid.ensureCols(3);
    try testing.expectEqual(grid.rows(), 0);
    try testing.expectEqual(grid.cols(), 0);
    const pos = Pos.init(1, 2);
    try testing.expectEqual(grid.get(pos), default);
    try grid.set(pos, treasure);
    try testing.expectEqual(grid.get(pos), treasure);
    try testing.expectEqual(grid.rows(), 1);
    try testing.expectEqual(grid.cols(), 1);
}
