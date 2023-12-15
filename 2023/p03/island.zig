const std = @import("std");
const testing = std.testing;
const Grid = @import("./util/grid.zig").Grid;
const Pos = @import("./util/grid.zig").Pos;

const Allocator = std.mem.Allocator;

pub const Engine = struct {
    const SYMBOL_GEAR = '*';

    const Data = Grid(Symbol);

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

    const Symbol = union(enum) {
        symbol: u8,
        index: usize,
    };

    num: Number,
    numbers: std.ArrayList(usize),
    symbols: std.ArrayList(Pos),
    data: Data,
    found: std.AutoHashMap(usize, void),

    pub fn init(allocator: Allocator) Engine {
        const empty = Symbol{ .symbol = '.' };
        var self = Engine{
            .num = Number.init(),
            .numbers = std.ArrayList(usize).init(allocator),
            .symbols = std.ArrayList(Pos).init(allocator),
            .data = Data.init(allocator, empty),
            .found = std.AutoHashMap(usize, void).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Engine) void {
        self.found.deinit();
        self.data.deinit();
        self.symbols.deinit();
        self.numbers.deinit();
    }

    pub fn addLine(self: *Engine, line: []const u8) !void {
        const rows = self.data.rows();
        try self.data.ensureCols(line.len);
        try self.data.ensureExtraRow();
        self.num.reset();
        for (line, 0..) |c, col| {
            switch (c) {
                '.' => try self.checkAndStoreNumber(rows, col),
                '0'...'9' => self.num.addDigit(c, col),
                else => try self.checkAndStoreSymbol(rows, c, col), // will also check number
            }
        }
        try self.checkAndStoreNumber(rows, self.data.cols()); // if last is a number
    }

    pub fn show(self: Engine) void {
        std.debug.print("Engine {} x {}\n", .{ self.data.rows(), self.data.cols() });
        for (0..self.data.rows()) |y| {
            for (0..self.data.cols()) |x| {
                const symbol = self.data.get(x, y);
                var c: u8 = '.';
                switch (symbol) {
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
                std.debug.print("{c}", .{c});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn getSumPartNumbers(self: *Engine) !usize {
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

    pub fn getSumGearRatios(self: *Engine) !usize {
        var sum: usize = 0;
        for (self.symbols.items) |symbol| {
            const pos = self.data.get(symbol.x, symbol.y);
            switch (pos) {
                .index => unreachable,
                .symbol => |s| {
                    if (s != SYMBOL_GEAR) continue;

                    try self.findNeighbors(symbol.x, symbol.y);
                    if (self.found.count() != 2) continue;

                    var prod: usize = 1;
                    var it = self.found.keyIterator();
                    while (it.next()) |p| {
                        const num = self.numbers.items[p.*];
                        prod *= num;
                    }
                    sum += prod;
                },
            }
        }
        return sum;
    }

    fn checkAndStoreNumber(self: *Engine, rows: usize, end: usize) !void {
        if (self.num.value == 0) return;

        const value = Symbol{ .index = self.numbers.items.len };
        try self.numbers.append(self.num.value);
        for (self.num.beg..end) |col| {
            try self.data.set(col, rows, value);
        }
        self.num.reset();
    }

    fn checkAndStoreSymbol(self: *Engine, rows: usize, symbol: u8, col: usize) !void {
        try self.checkAndStoreNumber(rows, col);

        const value = Symbol{ .symbol = symbol };
        const pos = Pos.init(col, rows);
        try self.data.set(pos.x, pos.y, value);
        try self.symbols.append(pos);
    }

    fn findNeighbors(self: *Engine, x: usize, y: usize) !void {
        self.found.clearRetainingCapacity();
        var cx: isize = @intCast(x);
        var cy: isize = @intCast(y);

        var dx: isize = -1;
        while (dx <= 1) : (dx += 1) {
            const px = cx + dx;
            if (px < 0 or px >= self.data.cols()) continue;

            var dy: isize = -1;
            while (dy <= 1) : (dy += 1) {
                if (dx == 0 and dy == 0) continue;

                const py = cy + dy;
                if (py < 0 or py >= self.data.rows()) continue;

                const pos = Pos.init(@intCast(px), @intCast(py));
                const neighbor = self.data.get(pos.x, pos.y);
                switch (neighbor) {
                    .symbol => continue,
                    .index => |p| _ = try self.found.getOrPut(p),
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

    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try engine.addLine(line);
    }
    // engine.show();

    const sum = try engine.getSumPartNumbers();
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

    var engine = Engine.init(std.testing.allocator);
    defer engine.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try engine.addLine(line);
    }
    // engine.show();

    const sum = try engine.getSumGearRatios();
    const expected = @as(usize, 467835);
    try testing.expectEqual(expected, sum);
}
