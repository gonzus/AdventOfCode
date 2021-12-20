const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const Map = struct {
    pub const Mode = enum { TEST, RUN }; // what a cheat

    const State = enum { ALGO, DATA };

    const Pos = struct {
        x: isize,
        y: isize,

        pub fn init(x: isize, y: isize) Pos {
            var self = Pos{ .x = x, .y = y };
            return self;
        }
    };

    const Grid = struct {
        min: Pos,
        max: Pos,
        data: std.AutoHashMap(Pos, u8),
        default: u8,

        pub fn init() Grid {
            var self = Grid{
                .min = Pos.init(std.math.maxInt(isize), std.math.maxInt(isize)),
                .max = Pos.init(std.math.minInt(isize), std.math.minInt(isize)),
                .data = std.AutoHashMap(Pos, u8).init(allocator),
                .default = 0,
            };
            return self;
        }

        pub fn deinit(self: *Grid) void {
            self.data.deinit();
        }

        pub fn reset(self: *Grid) void {
            self.data.clearRetainingCapacity();
            self.min = Pos.init(std.math.maxInt(isize), std.math.maxInt(isize));
            self.max = Pos.init(std.math.minInt(isize), std.math.minInt(isize));
        }

        pub fn get_pos(self: Grid, x: isize, y: isize) u8 {
            const pos = Pos.init(x, y);
            const entry = self.data.getEntry(pos);
            if (entry) |e| {
                return e.value_ptr.*;
            }
            return self.default;
        }

        pub fn put_pos(self: *Grid, x: isize, y: isize, c: u8) !void {
            const pos = Pos.init(x, y);
            try self.data.put(pos, c);
            if (self.min.x > x) self.min.x = x;
            if (self.min.y > y) self.min.y = y;
            if (self.max.x < x) self.max.x = x;
            if (self.max.y < y) self.max.y = y;
        }
    };

    mode: Mode,
    state: State,
    width: usize,
    height: usize,
    pos: usize,
    pixel: [512]u1,
    cur: usize,
    grid: [2]Grid,

    pub fn init(mode: Mode) Map {
        var self = Map{
            .mode = mode,
            .state = State.ALGO,
            .width = 0,
            .height = 0,
            .pos = 0,
            .pixel = [_]u1{0} ** 512,
            .cur = 0,
            .grid = undefined,
        };
        for (self.grid) |*g| {
            g.* = Grid.init();
        }
        return self;
    }

    pub fn deinit(self: *Map) void {
        for (self.grid) |*g| {
            g.*.deinit();
        }
    }

    pub fn process_line(self: *Map, data: []const u8) !void {
        if (data.len == 0) {
            self.state = State.DATA;
            self.cur = 0;
            self.grid[self.cur].reset();
            return;
        }

        switch (self.state) {
            State.ALGO => {
                // although it is said the algo comes in a single line, it is more readable to support multiple lines
                for (data) |c, p| {
                    if (c != '#') continue;
                    self.pixel[self.pos + p] = 1;
                }
                self.pos += data.len;

                // I know, I'm a fucking cheat
                switch (self.mode) {
                    Mode.TEST => {
                        self.grid[0].default = '.';
                        self.grid[1].default = '.';
                    },
                    Mode.RUN => {
                        self.grid[0].default = data[511];
                        self.grid[1].default = data[0];
                    },
                }
            },

            State.DATA => {
                if (self.width == 0) self.width = data.len;
                if (self.width != data.len) unreachable;

                const y = self.height;
                for (data) |c, x| {
                    const sx = @intCast(isize, x);
                    const sy = @intCast(isize, y);
                    try self.grid[self.cur].put_pos(sx, sy, c);
                }
                self.height += 1;
            },
        }
    }

    pub fn process(self: *Map, steps: usize) !void {
        var n: usize = 0;
        // self.show(n);
        while (n < steps) {
            try self.iterate();
            n += 1;
            // self.show(n);
        }
    }

    pub fn count_pixels_on(self: Map) usize {
        var count: usize = 0;
        var sy: isize = self.grid[self.cur].min.y;
        while (sy <= self.grid[self.cur].max.y) : (sy += 1) {
            var sx: isize = self.grid[self.cur].min.x;
            while (sx <= self.grid[self.cur].max.x) : (sx += 1) {
                const b = self.grid[self.cur].get_pos(sx, sy);
                if (b != '#') continue;
                count += 1;
            }
        }
        return count;
    }

    fn iterate(self: *Map) !void {
        var nxt = 1 - self.cur;
        self.grid[nxt].reset();
        // std.debug.warn("PROCESS {} -> {}, {} to {}\n", .{ self.cur, nxt, self.grid[self.cur].min, self.grid[self.cur].max });
        var sy: isize = self.grid[self.cur].min.y - 1;
        while (sy <= self.grid[self.cur].max.y + 1) : (sy += 1) {
            var sx: isize = self.grid[self.cur].min.x - 1;
            while (sx <= self.grid[self.cur].max.x + 1) : (sx += 1) {
                var pos: usize = 0;
                var dy: isize = -1;
                while (dy <= 1) : (dy += 1) {
                    var py = sy + dy;
                    var dx: isize = -1;
                    while (dx <= 1) : (dx += 1) {
                        var px = sx + dx;
                        const b = self.grid[self.cur].get_pos(px, py);
                        pos <<= 1;
                        if (b != '#') continue;
                        pos |= 1;
                    }
                }
                var c = self.pixel[pos];
                try self.grid[nxt].put_pos(sx, sy, if (c == 1) '#' else '.');
            }
        }
        self.cur = nxt;
    }

    fn show(self: *Map, step: usize) void {
        std.debug.warn("SHOW STEP {}, POS {}\n", .{ step, self.cur });
        var sy: isize = self.grid[self.cur].min.y;
        while (sy <= self.grid[self.cur].max.y) : (sy += 1) {
            var sx: isize = self.grid[self.cur].min.x;
            while (sx <= self.grid[self.cur].max.x) : (sx += 1) {
                const b = self.grid[self.cur].get_pos(sx, sy);
                std.debug.warn("{c}", .{b});
            }
            std.debug.warn("\n", .{});
        }
    }
};

test "sample part a" {
    const data: []const u8 =
        \\..#.#..#####.#.#.#.###.##.....###.##.#..###.####..#####..#....#..#..##..##
        \\#..######.###...####..#..#####..##..#.#####...##.#.#..#.##..#.#......#.###
        \\.######.###.####...#.##.##..#..#..#####.....#.#....###..#.##......#.....#.
        \\.#..#..##..#...##.######.####.####.#.#...#.......#..#.#.#...####.##.#.....
        \\.#..#...##.#.##..#...##.#.##..###.#......#.#.......#.#.#.####.###.##...#..
        \\...####.#..#..#.##.#....##..#.####....##...##..#...#......#.#.......#.....
        \\..##..####..#...#.#.#...##..#.#..###..#####........#..####......#..#
        \\
        \\#..#.
        \\#....
        \\##..#
        \\..#..
        \\..###
    ;

    var map = Map.init(Map.Mode.TEST);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }

    try map.process(2);
    const count = map.count_pixels_on();
    try testing.expect(count == 35);
}

test "sample part b" {
    const data: []const u8 =
        \\..#.#..#####.#.#.#.###.##.....###.##.#..###.####..#####..#....#..#..##..##
        \\#..######.###...####..#..#####..##..#.#####...##.#.#..#.##..#.#......#.###
        \\.######.###.####...#.##.##..#..#..#####.....#.#....###..#.##......#.....#.
        \\.#..#..##..#...##.######.####.####.#.#...#.......#..#.#.#...####.##.#.....
        \\.#..#...##.#.##..#...##.#.##..###.#......#.#.......#.#.#.####.###.##...#..
        \\...####.#..#..#.##.#....##..#.####....##...##..#...#......#.#.......#.....
        \\..##..####..#...#.#.#...##..#.#..###..#####........#..####......#..#
        \\
        \\#..#.
        \\#....
        \\##..#
        \\..#..
        \\..###
    ;

    var map = Map.init(Map.Mode.TEST);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }

    try map.process(50);
    const count = map.count_pixels_on();
    try testing.expect(count == 3351);
}
