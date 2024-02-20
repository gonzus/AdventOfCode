const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Disk = struct {
    const HASH_SIZE = 256;
    const HASH_ROUNDS = 64;
    const DISK_SIZE = 128;
    const BITS_SIZE = DISK_SIZE / 8;

    allocator: Allocator,
    buf: [100]u8,
    key: []const u8,
    numbers: [HASH_SIZE]usize,
    bits: [BITS_SIZE]usize,
    pos: usize,
    skip: usize,
    grid: [DISK_SIZE][DISK_SIZE]u8,
    seen: std.AutoHashMap(usize, void),

    pub fn init(allocator: Allocator) Disk {
        return .{
            .allocator = allocator,
            .buf = undefined,
            .key = undefined,
            .numbers = undefined,
            .bits = undefined,
            .pos = 0,
            .skip = 0,
            .grid = undefined,
            .seen = std.AutoHashMap(usize, void).init(allocator),
        };
    }

    pub fn deinit(self: *Disk) void {
        self.seen.deinit();
    }

    pub fn addLine(self: *Disk, line: []const u8) !void {
        std.mem.copyForwards(u8, &self.buf, line);
        self.key = self.buf[0..line.len];
    }

    pub fn getUsedSquares(self: *Disk) !usize {
        var total: usize = 0;
        for (0..DISK_SIZE) |row| {
            total += try self.getHashBits(row);
        }
        return total;
    }

    pub fn countRegions(self: *Disk) !usize {
        for (0..DISK_SIZE) |r| {
            _ = try self.getHashBits(r);
            for (0..BITS_SIZE) |b| {
                var m: u8 = 1;
                for (0..8) |p| {
                    const c: u8 = if (self.bits[b] & m != 0) '#' else '.';
                    self.grid[b * 8 + 8 - p - 1][r] = c;
                    m <<= 1;
                }
            }
        }
        var count: usize = 0;
        for (0..DISK_SIZE) |y| {
            for (0..DISK_SIZE) |x| {
                if (self.grid[x][y] != '#') continue;
                if (self.seen.contains(encode(x, y))) continue;
                count += 1;
                try self.walkRegion(x, y);
            }
        }
        return count;
    }

    fn walkRegion(self: *Disk, x: usize, y: usize) !void {
        try self.seen.put(encode(x, y), {});
        const dxs = [_]isize{ -1, 1, 0, 0 };
        const dys = [_]isize{ 0, 0, 1, -1 };
        for (dxs, dys) |dx, dy| {
            var ix: isize = @intCast(x);
            ix += dx;
            if (ix < 0 or ix >= DISK_SIZE) continue;

            var iy: isize = @intCast(y);
            iy += dy;
            if (iy < 0 or iy >= DISK_SIZE) continue;

            const nx: usize = @intCast(ix);
            const ny: usize = @intCast(iy);
            if (self.grid[nx][ny] != '#') continue;
            if (self.seen.contains(encode(nx, ny))) continue;
            try self.walkRegion(nx, ny);
        }
    }

    fn encode(x: usize, y: usize) usize {
        return x * 1000 + y;
    }

    fn resetHash(self: *Disk) void {
        for (0..HASH_SIZE) |p| {
            self.numbers[p] = p;
        }
        self.pos = 0;
        self.skip = 0;
    }

    fn getHashBits(self: *Disk, row: usize) !usize {
        self.resetHash();
        var buf: [100]u8 = undefined;
        var len: usize = 0;
        std.mem.copyForwards(u8, buf[len..], self.key);
        len += self.key.len;
        buf[len] = '-';
        len += 1;
        const num = try std.fmt.bufPrint(buf[len..], "{d}", .{row});
        len += num.len;
        const extra = [_]u8{ 17, 31, 73, 47, 23 };
        std.mem.copyForwards(u8, buf[len..], &extra);
        len += extra.len;
        const str = buf[0..len];

        for (0..HASH_ROUNDS) |_| {
            try self.hashRound(str);
        }

        var count: usize = 0;
        for (0..BITS_SIZE) |r| {
            var v: usize = 0;
            for (0..BITS_SIZE) |c| {
                v ^= self.numbers[r * BITS_SIZE + c];
            }
            count += @popCount(v);
            self.bits[r] = v;
        }
        return count;
    }

    fn hashRound(self: *Disk, str: []const u8) !void {
        for (str) |c| {
            const middle = c / 2;
            for (0..middle) |pos| {
                const s = (self.pos + pos) % HASH_SIZE;
                const t = (self.pos + c - pos - 1) % HASH_SIZE;
                std.mem.swap(usize, &self.numbers[s], &self.numbers[t]);
            }
            self.pos = (self.pos + c + self.skip) % HASH_SIZE;
            self.skip += 1;
        }
    }
};

test "sample part 1" {
    const data =
        \\flqrgnkx
    ;

    var disk = Disk.init(testing.allocator);
    defer disk.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try disk.addLine(line);
    }

    const count = try disk.getUsedSquares();
    const expected = @as(usize, 8108);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\flqrgnkx
    ;

    var disk = Disk.init(testing.allocator);
    defer disk.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try disk.addLine(line);
    }

    const count = try disk.countRegions();
    const expected = @as(usize, 1242);
    try testing.expectEqual(expected, count);
}
