const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const Map = struct {
    const SIZE = 150;

    width: usize,
    height: usize,
    pixel: [3][SIZE][SIZE]u8,
    cur: usize,

    pub fn init() Map {
        var self = Map{
            .width = 0,
            .height = 0,
            .pixel = undefined,
            .cur = 0,
        };
        return self;
    }

    pub fn deinit(_: *Map) void {}

    pub fn process_line(self: *Map, data: []const u8) !void {
        if (self.width == 0) self.width = data.len;
        if (self.width != data.len) unreachable;

        const y = self.height;
        for (data) |c, x| {
            self.pixel[self.cur][x][y] = c;
        }
        self.height += 1;
    }

    pub fn iterate(self: *Map) bool {
        // 0 is always where we start
        // 1 is next place; since we run two iters per step, we go back to 0
        // 2 is a copy of the previous step
        {
            var y: usize = 0;
            while (y < self.height) : (y += 1) {
                var x: usize = 0;
                while (x < self.width) : (x += 1) {
                    self.pixel[2][x][y] = self.pixel[0][x][y];
                }
            }
        }

        var h: usize = 0;
        while (h < 2) : (h += 1) {
            var nxt = 1 - self.cur;
            {
                var y: usize = 0;
                while (y < self.height) : (y += 1) {
                    var x: usize = 0;
                    while (x < self.width) : (x += 1) {
                        self.pixel[nxt][x][y] = '.';
                    }
                }
            }
            var y: usize = 0;
            while (y < self.height) : (y += 1) {
                var x: usize = 0;
                while (x < self.width) : (x += 1) {
                    const c = self.pixel[self.cur][x][y];
                    if (c == '.') continue;

                    if (h == 0) {
                        if (c != '>') {
                            self.pixel[nxt][x][y] = c;
                        } else {
                            const nx = (x + 1) % self.width;
                            const n = self.pixel[self.cur][nx][y];
                            if (n == '.') {
                                self.pixel[nxt][nx][y] = c;
                            } else {
                                self.pixel[nxt][x][y] = c;
                            }
                        }
                    }

                    if (h == 1) {
                        if (c != 'v') {
                            self.pixel[nxt][x][y] = c;
                        } else {
                            const ny = (y + 1) % self.height;
                            const n = self.pixel[self.cur][x][ny];
                            if (n == '.') {
                                self.pixel[nxt][x][ny] = c;
                            } else {
                                self.pixel[nxt][x][y] = c;
                            }
                        }
                    }
                }
            }
            self.cur = nxt;
        }
        {
            var y: usize = 0;
            while (y < self.height) : (y += 1) {
                var x: usize = 0;
                while (x < self.width) : (x += 1) {
                    if (self.pixel[2][x][y] != self.pixel[0][x][y]) return false;
                }
            }
            return true;
        }
    }

    pub fn iterate_until_stopped(self: *Map) usize {
        var n: usize = 0;
        while (true) {
            n += 1;
            const done = self.iterate();
            // std.debug.print("ITER {}\n", .{n});
            // self.show();
            if (done) break;
        }
        return n;
    }

    fn show(self: *Map) void {
        var y: usize = 0;
        while (y < self.height) : (y += 1) {
            var x: usize = 0;
            while (x < self.width) : (x += 1) {
                std.debug.print("{c}", .{self.pixel[self.cur][x][y]});
            }
            std.debug.print("\n", .{});
        }
    }
};

test "sample part a" {
    const data: []const u8 =
        \\v...>>.vv>
        \\.vv>>.vv..
        \\>>.>v>...v
        \\>>v>>.>.v.
        \\v>v.vv.v..
        \\>.>>..v...
        \\.vv..>.>v.
        \\v.v..>>v.v
        \\....v..v.>
    ;

    var map = Map.init();
    defer map.deinit();
    std.debug.print("\n", .{});

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    map.show();

    const iters = map.iterate_until_stopped();
    try testing.expect(iters == 58);
}
