const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const INFINITY = std.math.maxInt(usize);
    const SIZE = 60;
    const ANTENNAS = 10 + 26 + 26; // digits, lower, upper

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            return .{ .x = x, .y = y };
        }
    };

    harmonics: bool,
    grid: [SIZE][SIZE]u8,
    rows: usize,
    cols: usize,
    antennas: [ANTENNAS]std.ArrayList(Pos),
    antinodes: std.AutoHashMap(Pos, void),

    pub fn init(allocator: Allocator, harmonics: bool) Module {
        var self = Module{
            .harmonics = harmonics,
            .grid = undefined,
            .rows = 0,
            .cols = 0,
            .antennas = undefined,
            .antinodes = std.AutoHashMap(Pos, void).init(allocator),
        };
        for (0..ANTENNAS) |a| {
            self.antennas[a] = std.ArrayList(Pos).init(allocator);
        }

        return self;
    }

    pub fn deinit(self: *Module) void {
        for (0..ANTENNAS) |a| {
            self.antennas[a].deinit();
        }
        self.antinodes.deinit();
    }

    pub fn antennaCharToPos(c: u8) usize {
        return switch (c) {
            '0'...'9' => c - '0' + 0,
            'a'...'z' => c - 'a' + 10,
            'A'...'Z' => c - 'A' + 10 + 26,
            else => return INFINITY,
        };
    }

    pub fn antennaPosToChar(p: usize) u8 {
        const q: u8 = @intCast(p);
        return if (q >= 10 + 26)
            q - 36 + 'A'
        else if (q >= 10)
            q - 10 + 'a'
        else
            q + '0';
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        if (self.cols == 0) {
            self.cols = line.len;
        }
        if (self.cols != line.len) {
            return error.JaggedGrid;
        }
        const y = self.rows;
        for (line, 0..) |c, x| {
            const p = antennaCharToPos(c);
            if (p != INFINITY) {
                try self.antennas[p].append(Pos.init(x, y));
            }
            self.grid[x][y] = c;
        }
        self.rows += 1;
    }

    pub fn show(self: *Module) void {
        std.debug.print("Grid {} x {}\n", .{ self.rows, self.cols });
        for (0..self.rows) |y| {
            for (0..self.cols) |x| {
                std.debug.print("{c}", .{self.grid[x][y]});
            }
            std.debug.print("\n", .{});
        }
        for (0..ANTENNAS) |a| {
            const list = self.antennas[a].items;
            if (list.len <= 0) continue;
            std.debug.print("Antennas for {c}:", .{antennaPosToChar(a)});
            for (list) |e| {
                std.debug.print(" {}:{}", .{ e.x, e.y });
            }
            std.debug.print("\n", .{});
        }
    }

    fn placeAntiNode(self: *Module, x: isize, y: isize) !usize {
        if (x < 0 or x >= self.cols) return 0;
        if (y < 0 or y >= self.rows) return 0;
        const nx: usize = @intCast(x);
        const ny: usize = @intCast(y);
        _ = try self.antinodes.getOrPut(Pos.init(nx, ny));
        return 1;
    }

    pub fn countAntiNodes(self: *Module) !usize {
        for (0..ANTENNAS) |a| {
            const list = self.antennas[a].items;
            if (list.len < 2) continue;
            for (0..list.len) |p0| {
                const ix0: isize = @intCast(list[p0].x);
                const iy0: isize = @intCast(list[p0].y);
                for (p0 + 1..list.len) |p1| {
                    const ix1: isize = @intCast(list[p1].x);
                    const iy1: isize = @intCast(list[p1].y);
                    const dx = ix1 - ix0;
                    const dy = iy1 - iy0;
                    var p: isize = 0;
                    if (!self.harmonics) {
                        p = 1; // antenna itself is not an antinode
                    }
                    while (true) : (p += 1) {
                        var placed: usize = 0;
                        placed += try self.placeAntiNode(ix0 - p * dx, iy0 - p * dy);
                        placed += try self.placeAntiNode(ix1 + p * dx, iy1 + p * dy);
                        if (placed == 0) break; // out of grid
                        if (!self.harmonics) break; // only one try
                    }
                }
            }
        }
        return self.antinodes.count();
    }
};

test "sample part 1" {
    const data =
        \\............
        \\........0...
        \\.....0......
        \\.......0....
        \\....0.......
        \\......A.....
        \\............
        \\............
        \\........A...
        \\.........A..
        \\............
        \\............
    ;

    var module = Module.init(testing.allocator, false);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }
    // module.show();

    const count = try module.countAntiNodes();
    const expected = @as(usize, 14);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\............
        \\........0...
        \\.....0......
        \\.......0....
        \\....0.......
        \\......A.....
        \\............
        \\............
        \\........A...
        \\.........A..
        \\............
        \\............
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }
    // module.show();

    const count = try module.countAntiNodes();
    const expected = @as(usize, 34);
    try testing.expectEqual(expected, count);
}
