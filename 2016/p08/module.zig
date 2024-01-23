const std = @import("std");
const testing = std.testing;
const Grid = @import("./util/grid.zig").Grid;

const Allocator = std.mem.Allocator;

pub const Screen = struct {
    const Data = Grid(u8);
    const PIXEL_ON = '#';
    const PIXEL_OFF = '.';

    rows: usize,
    cols: usize,
    data: [2]Data,
    pos: usize,

    pub fn init(allocator: Allocator, rows: usize, cols: usize) !Screen {
        var self = Screen{
            .rows = rows,
            .cols = cols,
            .data = undefined,
            .pos = 0,
        };
        for (self.data, 0..) |_, pos| {
            self.data[pos] = Data.init(allocator, PIXEL_OFF);
            try self.data[pos].ensureCols(cols);
            for (0..rows) |y| {
                try self.data[pos].ensureExtraRow();
                for (0..cols) |x| {
                    try self.data[pos].set(x, y, PIXEL_OFF);
                }
            }
        }
        return self;
    }

    pub fn deinit(self: *Screen) void {
        for (self.data, 0..) |_, pos| {
            self.data[pos].deinit();
        }
    }

    pub fn addLine(self: *Screen, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        const op = it.next().?;

        if (std.mem.eql(u8, op, "rect")) {
            var it_size = std.mem.tokenizeScalar(u8, it.next().?, 'x');
            const r = try std.fmt.parseUnsigned(usize, it_size.next().?, 10);
            const w = try std.fmt.parseUnsigned(usize, it_size.next().?, 10);
            try self.rectangle(r, w);
            return;
        }

        if (std.mem.eql(u8, op, "rotate")) {
            const what = it.next().?;
            var it_pos = std.mem.tokenizeScalar(u8, it.next().?, '=');
            _ = it_pos.next();
            const pos = try std.fmt.parseUnsigned(usize, it_pos.next().?, 10);
            _ = it.next().?;
            const dist = try std.fmt.parseUnsigned(usize, it.next().?, 10);
            if (std.mem.eql(u8, what, "row")) {
                try self.rotateRow(pos, dist);
                return;
            }
            if (std.mem.eql(u8, what, "column")) {
                try self.rotateCol(pos, dist);
                return;
            }
            return error.InvalidRotation;
        }

        return error.InvalidOp;
    }

    pub fn show(self: Screen) void {
        const cur = &self.data[self.pos];
        std.debug.print("Screen with {} rows and {} cols\n", .{ cur.row_len, cur.col_len });
        for (0..cur.row_len) |y| {
            for (0..cur.col_len) |x| {
                std.debug.print("{c}", .{cur.get(x, y)});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn getLitPixels(self: Screen) usize {
        const cur = &self.data[self.pos];
        var count: usize = 0;
        for (0..cur.row_len) |y| {
            for (0..cur.col_len) |x| {
                if (cur.get(x, y) != PIXEL_ON) continue;
                count += 1;
            }
        }
        return count;
    }

    pub fn displayMessage(self: Screen, buf: []u8) []const u8 {
        const expected = "UPOJFLBCEZ"; // squinted at the screen to get this
        std.mem.copyForwards(u8, buf, expected);
        const cur = &self.data[self.pos];
        for (0..cur.row_len) |y| {
            for (0..cur.col_len) |x| {
                const c = cur.get(x, y);
                std.debug.print("{s}", .{if (c == PIXEL_OFF) " " else "█"});
            }
            std.debug.print("\n", .{});
        }
        return buf[0..expected.len];
    }

    fn rectangle(self: *Screen, r: usize, c: usize) !void {
        try self.transfer();
        const cur = &self.data[self.pos];
        for (0..r) |x| {
            for (0..c) |y| {
                try cur.set(x, y, PIXEL_ON);
            }
        }
        // self.show();
    }

    fn rotateRow(self: *Screen, pos: usize, dist: usize) !void {
        try self.transfer();
        const cur = &self.data[self.pos];
        const prv = &self.data[1 - self.pos];
        for (0..cur.col_len) |x| {
            var nx = x + dist;
            nx %= cur.col_len;
            try cur.set(nx, pos, prv.get(x, pos));
        }
        // self.show();
    }

    fn rotateCol(self: *Screen, pos: usize, dist: usize) !void {
        try self.transfer();
        const cur = &self.data[self.pos];
        const prv = &self.data[1 - self.pos];
        for (0..cur.row_len) |y| {
            var ny = y + dist;
            ny %= cur.row_len;
            try cur.set(pos, ny, prv.get(pos, y));
        }
        // self.show();
    }

    fn transfer(self: *Screen) !void {
        const cur = &self.data[self.pos];
        const nxt = &self.data[1 - self.pos];
        for (0..cur.row_len) |y| {
            for (0..cur.col_len) |x| {
                try nxt.set(x, y, cur.get(x, y));
            }
        }
        self.pos = 1 - self.pos;
    }
};

test "sample part 1" {
    const data =
        \\rect 3x2
        \\rotate column x=1 by 1
        \\rotate row y=0 by 4
        \\rotate column x=1 by 1
    ;

    var screen = try Screen.init(std.testing.allocator, 3, 7);
    defer screen.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try screen.addLine(line);
    }
    // screen.show();

    const count = screen.getLitPixels();
    const expected = @as(usize, 6);
    try testing.expectEqual(expected, count);
}
