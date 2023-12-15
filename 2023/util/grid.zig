const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Direction = enum {
    N,
    W,
    S,
    E,

    pub fn parse(c: u8) Direction {
        const dir: Direction = @enumFromInt(c);
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
    x: usize,
    y: usize,

    pub fn init(x: usize, y: usize) Pos {
        var self = Pos{ .x = x, .y = y };
        return self;
    }

    pub fn initFromSigned(x: isize, y: isize) Pos {
        return Pos.init(@intCast(x), @intCast(y));
    }

    pub fn equal(self: Pos, other: Pos) bool {
        return self.x == other.x and self.y == other.y;
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

pub fn Grid(comptime T: type) type {
    return struct {
        const Self = @This();

        pub fn init(allocator: Allocator, default: T) Self {
            var self = Self{
                .allocator = allocator,
                .default = default,
                .data = undefined,
                .row_cap = 0,
                .row_len = 0,
                .col_cap = 0,
                .col_len = 0,
            };
            self.data.len = 0;
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.data);
        }

        pub fn ensureCols(self: *Self, new_cols: usize) !void {
            if (self.col_cap >= new_cols) return;
            const row_cap = @max(self.row_cap, new_cols); // estimate
            const new_size = row_cap * new_cols;
            var new_data = try self.allocator.realloc(self.data, new_size);
            for (self.row_cap * self.col_cap..new_size) |p| {
                new_data[p] = self.default;
            }
            self.data = new_data;
            self.row_cap = row_cap;
            self.col_cap = new_cols;
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

        pub fn set(self: *Self, x: usize, y: usize, val: T) !void {
            if (x < 0 or x >= self.col_cap or y < 0 or y >= self.row_cap)
                return error.InvalidPos;
            if (self.col_len <= x) self.col_len = x + 1;
            if (self.row_len <= y) self.row_len = y + 1;
            const pos = self.col_cap * y + x;
            self.data[pos] = val;
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
                .row_len = 0,
                .col_len = 0,
            };
            return self;
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
        }

        pub fn ensureCols(_: *Self, _: usize) !void {}

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
            const pos = Pos.init(x, y);
            const value = self.data.get(pos) orelse self.default;
            return value;
        }

        pub fn set(self: *Self, x: usize, y: usize, val: T) !void {
            const pos = Pos.init(x, y);
            const entry = try self.data.getOrPut(pos);
            entry.value_ptr.* = val;
            if (!entry.found_existing) {
                if (self.row_len <= y) self.row_len = y + 1;
                if (self.col_len <= x) self.col_len = x + 1;
            }
        }

        allocator: Allocator,
        default: T,
        data: std.AutoHashMap(Pos, T),
        row_len: usize,
        col_len: usize,
    };
}
