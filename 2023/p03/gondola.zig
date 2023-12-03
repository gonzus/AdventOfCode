const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Grid = struct {
    const SYMBOL_GEAR = '*';

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            var self = Pos{ .x = x, .y = y };
            return self;
        }
    };

    const Number = struct {
        value: usize,
        beg: usize,

        pub fn init() Number {
            var self: Number = undefined;
            self.reset();
            return self;
        }

        pub fn reset(self: *Number) void {
            self.value = 0;
            self.beg = 0;
        }

        pub fn addDigit(self: *Number, c: u8, col: usize) void {
            if (self.value == 0) self.beg = col;
            self.value *= 10;
            self.value += c - '0';
        }
    };

    const Data = union(enum) {
        symbol: u8,
        index: usize,
    };

    rows: usize,
    cols: usize,
    num: Number,
    numbers: std.ArrayList(usize),
    symbols: std.ArrayList(Pos),
    data: std.AutoHashMap(Pos, Data),
    found: std.AutoHashMap(usize, void),

    pub fn init(allocator: Allocator) Grid {
        var self = Grid{
            .rows = 0,
            .cols = 0,
            .num = Number.init(),
            .numbers = std.ArrayList(usize).init(allocator),
            .symbols = std.ArrayList(Pos).init(allocator),
            .data = std.AutoHashMap(Pos, Data).init(allocator),
            .found = std.AutoHashMap(usize, void).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Grid) void {
        self.found.deinit();
        self.data.deinit();
        self.symbols.deinit();
        self.numbers.deinit();
    }

    pub fn addLine(self: *Grid, line: []const u8) !void {
        if (self.cols < line.len) self.cols = line.len;
        self.num.reset();
        for (line, 0..) |c, col| {
            switch (c) {
                '.' => try self.checkAndStoreNumber(col),
                '0'...'9' => self.num.addDigit(c, col),
                else => try self.checkAndStoreSymbol(c, col), // will also check number
            }
        }
        try self.checkAndStoreNumber(self.cols); // if last is a number
        self.rows += 1;
    }

    pub fn show(self: Grid) void {
        std.debug.print("Grid {} x {}\n", .{ self.rows, self.cols });
        for (0..self.rows) |y| {
            for (0..self.cols) |x| {
                const entry = self.data.getEntry(Pos.init(x, y));
                var c: u8 = '.';
                if (entry) |e| {
                    switch (e.value_ptr.*) {
                        .symbol => |s| c = s,
                        .index => |j| {
                            if (j <= 9) {
                                c = @intCast(j + '0');
                            } else if (j <= 'Z' - 'A' + 10) {
                                c = @intCast(j - 10 + 'A');
                            } else {
                                c = '@';
                            }
                        },
                    }
                }
                std.debug.print("{c}", .{c});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn getSumPartNumbers(self: *Grid) !usize {
        var sum: usize = 0;
        for (self.symbols.items) |symbol| {
            try self.findNeighbors(symbol.x, symbol.y);
            var it = self.found.keyIterator();
            while (it.next()) |pos| {
                const num = self.numbers.items[pos.*];
                sum += num;
            }
        }
        return sum;
    }

    pub fn getSumGearRatios(self: *Grid) !usize {
        var sum: usize = 0;
        for (self.symbols.items) |symbol| {
            const entry = self.data.getEntry(symbol);
            if (entry) |e| {
                switch (e.value_ptr.*) {
                    .index => unreachable,
                    .symbol => |s| {
                        if (s != SYMBOL_GEAR) continue;

                        try self.findNeighbors(symbol.x, symbol.y);
                        if (self.found.count() != 2) continue;

                        var prod: usize = 1;
                        var it = self.found.keyIterator();
                        while (it.next()) |pos| {
                            const num = self.numbers.items[pos.*];
                            prod *= num;
                        }
                        sum += prod;
                    },
                }
            }
        }
        return sum;
    }

    fn checkAndStoreNumber(self: *Grid, end: usize) !void {
        if (self.num.value == 0) return;

        const value = Data{ .index = self.numbers.items.len };
        try self.numbers.append(self.num.value);
        for (self.num.beg..end) |col| {
            const pos = Pos.init(col, self.rows);
            try self.data.put(pos, value);
        }
        self.num.reset();
    }

    fn checkAndStoreSymbol(self: *Grid, symbol: u8, col: usize) !void {
        try self.checkAndStoreNumber(col);

        const value = Data{ .symbol = symbol };
        const pos = Pos.init(col, self.rows);
        try self.data.put(pos, value);
        try self.symbols.append(pos);
    }

    fn findNeighbors(self: *Grid, x: usize, y: usize) !void {
        self.found.clearRetainingCapacity();
        var cx: isize = @intCast(x);
        var cy: isize = @intCast(y);

        var dx: isize = -1;
        while (dx <= 1) : (dx += 1) {
            const px = cx + dx;
            if (px < 0 or px >= self.cols) continue;

            var dy: isize = -1;
            while (dy <= 1) : (dy += 1) {
                if (dx == 0 and dy == 0) continue;

                const py = cy + dy;
                if (py < 0 or py >= self.rows) continue;

                const pos = Pos.init(@intCast(px), @intCast(py));
                const neighbor = self.data.getEntry(pos);
                if (neighbor) |n| {
                    switch (n.value_ptr.*) {
                        .symbol => continue,
                        .index => |j| _ = try self.found.getOrPut(j),
                    }
                }
            }
        }
    }
};

test "sample part 1" {
    const data =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
    ;

    var grid = Grid.init(std.testing.allocator);
    defer grid.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try grid.addLine(line);
    }
    // grid.show();

    const sum = try grid.getSumPartNumbers();
    const expected = @as(usize, 4361);
    try testing.expectEqual(expected, sum);
}

test "sample part 2" {
    const data =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
    ;

    var grid = Grid.init(std.testing.allocator);
    defer grid.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try grid.addLine(line);
    }
    // grid.show();

    const sum = try grid.getSumGearRatios();
    const expected = @as(usize, 467835);
    try testing.expectEqual(expected, sum);
}
