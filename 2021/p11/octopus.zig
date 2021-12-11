const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const Octopus = struct {
    const SIZE = 10;

    width: usize,
    height: usize,
    cur: usize,
    grid: [2][SIZE][SIZE]usize,

    pub fn init() Octopus {
        var self = Octopus{
            .width = 0,
            .height = 0,
            .cur = 0,
            .grid = undefined,
        };
        return self;
    }

    pub fn deinit(_: *Octopus) void {}

    pub fn process_line(self: *Octopus, data: []const u8) !void {
        if (self.width == 0) self.width = data.len;
        if (self.width != data.len) unreachable;

        for (data) |c, x| {
            const n = c - '0';
            self.grid[self.cur][x][self.height] = n;
        }
        self.height += 1;
    }

    pub fn count_total_flashes_after_n_steps(self: *Octopus, n: usize) usize {
        var flashes: usize = 0;
        var step: usize = 0;
        while (step < n) : (step += 1) {
            flashes += self.run_step();
        }
        return flashes;
    }

    pub fn count_steps_until_simultaneous_flash(self: *Octopus) usize {
        var step: usize = 0;
        while (!self.all_flashed()) : (step += 1) {
            _ = self.run_step();
        }
        return step;
    }

    fn show(self: Octopus, pos: usize) void {
        var y: usize = 0;
        while (y < SIZE) : (y += 1) {
            var x: usize = 0;
            while (x < SIZE) : (x += 1) {
                const n = @intCast(u8, self.grid[pos][x][y]);
                const c = if (n == 0) '*' else (n + '0');
                std.debug.warn("{c}", .{c});
            }
            std.debug.warn("\n", .{});
        }
        std.debug.warn("\n", .{});
    }

    fn increment_energy(self: *Octopus, delta: usize) usize {
        var flashes: usize = 0;
        var x: usize = 0;
        while (x < SIZE) : (x += 1) {
            var y: usize = 0;
            while (y < SIZE) : (y += 1) {
                self.grid[self.cur][x][y] += delta;
                if (self.grid[self.cur][x][y] == 10) {
                    flashes += 1;
                }
            }
        }
        return flashes;
    }

    fn count_neighbors(self: Octopus, cur: usize, x: usize, y: usize, n: usize) usize {
        var delta: usize = 0;
        var dx: isize = -1;
        while (dx <= 1) : (dx += 1) {
            var dy: isize = -1;
            while (dy <= 1) : (dy += 1) {
                if (dx == 0 and dy == 0) continue;
                var sx = @intCast(isize, x) + dx;
                if (sx < 0 or sx >= SIZE) continue;
                var sy = @intCast(isize, y) + dy;
                if (sy < 0 or sy >= SIZE) continue;
                var nx = @intCast(usize, sx);
                var ny = @intCast(usize, sy);
                if (self.grid[cur][nx][ny] == n) delta += 1;
            }
        }
        return delta;
    }

    fn reset_energy(self: *Octopus) void {
        var x: usize = 0;
        while (x < SIZE) : (x += 1) {
            var y: usize = 0;
            while (y < SIZE) : (y += 1) {
                if (self.grid[self.cur][x][y] >= 10) {
                    self.grid[self.cur][x][y] = 0;
                }
            }
        }
    }

    fn run_step(self: *Octopus) usize {
        var total_flashes: usize = self.increment_energy(1);
        var cur: usize = self.cur;
        var nxt: usize = 1 - cur;
        while (true) {
            var flashes: usize = 0;
            var x: usize = 0;
            while (x < SIZE) : (x += 1) {
                var y: usize = 0;
                while (y < SIZE) : (y += 1) {
                    const delta = self.count_neighbors(cur, x, y, 10);
                    var new: usize = self.grid[cur][x][y] + delta;
                    if (new >= 10) {
                        if (self.grid[cur][x][y] < 10) {
                            flashes += 1;
                            self.grid[nxt][x][y] = 10;
                        } else {
                            self.grid[nxt][x][y] = 11;
                        }
                    } else {
                        self.grid[nxt][x][y] = new;
                    }
                }
            }
            cur = 1 - cur;
            nxt = 1 - nxt;
            if (flashes == 0) break;
            total_flashes += flashes;
        }
        self.cur = cur;
        self.reset_energy();
        return total_flashes;
    }

    fn all_flashed(self: Octopus) bool {
        var x: usize = 0;
        while (x < SIZE) : (x += 1) {
            var y: usize = 0;
            while (y < SIZE) : (y += 1) {
                if (self.grid[self.cur][x][y] > 0) return false;
            }
        }
        return true;
    }
};

test "sample part a" {
    const data: []const u8 =
        \\5483143223
        \\2745854711
        \\5264556173
        \\6141336146
        \\6357385478
        \\4167524645
        \\2176841721
        \\6882881134
        \\4846848554
        \\5283751526
    ;

    var octopus = Octopus.init();
    defer octopus.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try octopus.process_line(line);
    }
    const total_flashes = octopus.count_total_flashes_after_n_steps(100);
    try testing.expect(total_flashes == 1656);
}

test "sample part b" {
    const data: []const u8 =
        \\5483143223
        \\2745854711
        \\5264556173
        \\6141336146
        \\6357385478
        \\4167524645
        \\2176841721
        \\6882881134
        \\4846848554
        \\5283751526
    ;

    var octopus = Octopus.init();
    defer octopus.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try octopus.process_line(line);
    }
    const steps = octopus.count_steps_until_simultaneous_flash();
    try testing.expect(steps == 195);
}
