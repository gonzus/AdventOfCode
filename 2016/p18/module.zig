const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Room = struct {
    allocator: Allocator,
    line_buf: [2][150]u8,
    line_len: usize,
    pos: usize,

    pub fn init(allocator: Allocator) Room {
        return .{
            .allocator = allocator,
            .line_buf = undefined,
            .line_len = 0,
            .pos = 0,
        };
    }

    pub fn addLine(self: *Room, line: []const u8) !void {
        if (self.line_len == 0) self.line_len = line.len;
        if (self.line_len != line.len) return error.InvalidLine;
        std.mem.copyForwards(u8, &self.line_buf[self.pos], line);
    }

    pub fn getSafeTiles(self: *Room, rows: usize) !usize {
        var count: usize = 0;
        for (0..rows) |_| {
            const pos = self.pos;
            const nxt = 1 - pos;
            for (0..self.line_len) |p| {
                if (self.line_buf[pos][p] == '.') count += 1;
                var next: u8 = '.';
                const l: u8 = if (p > 0) self.line_buf[pos][p - 1] else '.';
                const c: u8 = self.line_buf[pos][p];
                const r: u8 = if (p < self.line_len - 1) self.line_buf[pos][p + 1] else '.';
                if (l == '^' and c == '^' and r != '^') next = '^';
                if (l != '^' and c == '^' and r == '^') next = '^';
                if (l == '^' and c != '^' and r != '^') next = '^';
                if (l != '^' and c != '^' and r == '^') next = '^';
                self.line_buf[nxt][p] = next;
            }
            self.pos = nxt;
        }
        return count;
    }
};

test "sample part 1" {
    const data =
        \\.^^.^.^^^^
    ;

    var room = Room.init(testing.allocator);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try room.addLine(line);
    }

    const count = try room.getSafeTiles(10);
    const expected = @as(usize, 38);
    try testing.expectEqual(expected, count);
}
