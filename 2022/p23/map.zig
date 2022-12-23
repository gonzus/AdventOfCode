const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Map = struct {
    const INFINITY = std.math.maxInt(usize);
    const OFFSET = 1_000_000;

    const Direction = enum(u8) {
        N = 0,
        NE = 1,
        E = 2,
        SE = 3,
        S = 4,
        SW = 5,
        W = 6,
        NW = 7,

        pub fn direction_for_deltas(dx: isize, dy: isize) Direction {
            if (dy == -1 and dx == -1) return .NW;
            if (dy == -1 and dx ==  0) return .N;
            if (dy == -1 and dx ==  1) return .NE;
            if (dy ==  0 and dx == -1) return .W;
            if (dy ==  0 and dx ==  1) return .E;
            if (dy ==  1 and dx == -1) return .SW;
            if (dy ==  1 and dx ==  0) return .S;
            if (dy ==  1 and dx ==  1) return .SE;
            unreachable;
        }
    };

    const Cell = enum(u8) {
        Empty = '.',
        Elf  = '#',

        pub fn parse(c: u8) Cell {
            return switch (c) {
                '.' => .Empty,
                '#' => .Elf,
                else => unreachable,
            };
        }
    };

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            return Pos{.x = x, .y = y};
        }
    };

    const Elf = struct {
        current: Pos,
        wants_to_move: bool,
        next: Pos,

        pub fn init(pos: Pos) Elf {
            return Elf{.current = pos, .wants_to_move = false, .next = Pos.init(INFINITY, INFINITY)};
        }
    };

    allocator: Allocator,
    grids: [2]std.AutoHashMap(Pos, Cell),
    elves: [2]std.ArrayList(Elf),
    current: usize,
    preferred_move: usize,
    rows: usize,
    cols: usize,
    min: Pos,
    max: Pos,

    pub fn init(allocator: Allocator) Map {
        var self = Map{
            .allocator = allocator,
            .grids = undefined,
            .elves = undefined,
            .current = 0,
            .preferred_move = 0,
            .rows = 0,
            .cols = 0,
            .min = Pos.init(INFINITY, INFINITY),
            .max = Pos.init(0, 0),
        };
        var p: usize = 0;
        while (p < 2) : (p += 1) {
            self.grids[p] = std.AutoHashMap(Pos, Cell).init(allocator);
            self.elves[p] = std.ArrayList(Elf).init(allocator);
        }
        return self;
    }

    pub fn deinit(self: *Map) void {
        var p: usize = 0;
        while (p < 2) : (p += 1) {
            self.grids[p].deinit();
            self.elves[p].deinit();
        }
    }

    fn get_pos(self: Map, pos: Pos) Cell {
        return self.grids[self.current].get(pos) orelse .Empty;
    }

    fn set_pos(self: *Map, pos: Pos, cell: Cell) !void {
        try self.grids[self.current].put(pos, cell);
        if (self.min.x > pos.x) self.min.x = pos.x;
        if (self.min.y > pos.y) self.min.y = pos.y;
        if (self.max.x < pos.x) self.max.x = pos.x;
        if (self.max.y < pos.y) self.max.y = pos.y;
        if (cell == .Elf) {
            try self.elves[self.current].append(Elf.init(pos));
        }
    }

    pub fn add_line(self: *Map, line: []const u8) !void {
        if (self.cols == 0) self.cols = line.len;
        if (self.cols != line.len) unreachable;
        const y = self.rows;
        for (line) |c, x| {
            const cell = Cell.parse(c);
            const pos = Pos.init(x+OFFSET, y+OFFSET);
            try self.set_pos(pos, cell);
        }
        self.rows += 1;
    }

    pub fn show(self: Map) void {
        std.debug.print("-- Map -------\n", .{});
        var y: usize = self.min.y;
        while (y <= self.max.y) : (y += 1) {
            var x: usize = self.min.x;
            while (x <= self.max.x) : (x += 1) {
                const pos = Pos.init(x, y);
                const cell = self.get_pos(pos);
                std.debug.print("{c}", .{@enumToInt(cell)});
            }
            std.debug.print("\n", .{});
        }
    }

    fn run_round(self: *Map) !usize {
        const next = 1 - self.current;

        // reset next grid and elves list
        self.grids[next].clearRetainingCapacity();
        self.elves[next].clearRetainingCapacity();

        // keep track of how many elves are in each direction around current elf
        var around = std.AutoHashMap(Direction, usize).init(self.allocator);
        defer around.deinit();

        // keep track of how many elves have chosen each position
        var choices = std.AutoHashMap(Pos, usize).init(self.allocator);
        defer choices.deinit();

        const elves = self.elves[self.current].items;
        for (elves) |*elf| {
            elf.wants_to_move = false;

            // clear and prefill count around us -- easier to get values later
            around.clearRetainingCapacity();
            try around.put(.N , 0);
            try around.put(.NE, 0);
            try around.put(.E , 0);
            try around.put(.SE, 0);
            try around.put(.S , 0);
            try around.put(.SW, 0);
            try around.put(.W , 0);
            try around.put(.NW, 0);

            // count elves adjacent in each direction (and in total)
            const pos = elf.current;
            var total: usize = 0;
            var dy: isize = -1;
            while (dy <= 1) : (dy += 1) {
                var dx: isize = -1;
                while (dx <= 1) : (dx += 1) {
                    if (dy == 0 and dx == 0) continue; // skip elf's own position

                    const nx = @intCast(usize, @intCast(isize, pos.x) + dx);
                    const ny = @intCast(usize, @intCast(isize, pos.y) + dy);
                    const neighbor = Pos.init(nx, ny);
                    const cell = self.get_pos(neighbor);
                    if (cell != .Elf) continue; // no elf in this direction

                    const dir = Direction.direction_for_deltas(dx, dy);
                    var entry = around.getEntry(dir).?;
                    entry.value_ptr.* += 1;
                    total += 1;
                }
            }
            if (total == 0) continue; // no elves around this one, skip this elf

            var choice: Direction = undefined;
            var preferred_move = self.preferred_move; // start at current preferred move
            var n: usize = 0;
            while (n < 4) {
                if (preferred_move == 0 and around.get(.NW).? == 0 and around.get(.N).? == 0 and around.get(.NE).? == 0) {
                    choice = .N;
                    break;
                }
                if (preferred_move == 1 and around.get(.SW).? == 0 and around.get(.S).? == 0 and around.get(.SE).? == 0) {
                    choice = .S;
                    break;
                }
                if (preferred_move == 2 and around.get(.NW).? == 0 and around.get(.W).? == 0 and around.get(.SW).? == 0) {
                    choice = .W;
                    break;
                }
                if (preferred_move == 3 and around.get(.NE).? == 0 and around.get(.E).? == 0 and around.get(.SE).? == 0) {
                    choice = .E;
                    break;
                }
                preferred_move += 1;
                preferred_move %= 4;
                n += 1;
            }
            if (n >= 4) continue; // no possible move for this elf, skip

            // remember this elf wants to (and can) move
            var cy: isize = 0;
            var cx: isize = 0;
            switch (choice) {
                .N => cy = -1,
                .S => cy =  1,
                .E => cx =  1,
                .W => cx = -1,
                else => unreachable,
            }
            const nx = @intCast(usize, @intCast(isize, pos.x) + cx);
            const ny = @intCast(usize, @intCast(isize, pos.y) + cy);
            elf.next = Pos.init(nx, ny);
            elf.wants_to_move = true;

            // remember how many elves want to move to this position
            var result = try choices.getOrPut(elf.next);
            if (!result.found_existing) {
                result.value_ptr.* = 0;
            }
            result.value_ptr.* += 1;
        }

        // adjust preferred move for next round
        self.preferred_move += 1;
        self.preferred_move %= 4;

        // need to change to the next board / elves before setting positions
        self.current = next;

        // remember how many elves did in fact move
        var moving_elves: usize = 0;
        for (elves) |*elf| {
            var moved = false;
            if (elf.wants_to_move) {
                if (choices.get(elf.next)) |choice| {
                    if (choice == 1) {
                        try self.set_pos(elf.next, .Elf);
                        elf.current = elf.next;
                        moved = true;
                        moving_elves += 1;
                    }
                }
            }
            if (moved) continue;
            try self.set_pos(elf.current, .Elf); // place elf in its current position
        }

        return moving_elves;
    }

    fn count_empty_tiles(self: Map) usize {
        var count: usize = 0;
        var y: usize = self.min.y;
        while (y <= self.max.y) : (y += 1) {
            var x: usize = self.min.x;
            while (x <= self.max.x) : (x += 1) {
                const pos = Pos.init(x, y);
                const cell = self.get_pos(pos);
                if (cell == .Empty) count += 1;
            }
        }
        return count;
    }

    pub fn run_rounds(self: *Map, total: usize) !usize {
        var round: usize = 1;
        while (round <= total) : (round += 1) {
            _ = try self.run_round();
            // self.show();
        }
        return self.count_empty_tiles();
    }

    pub fn run_until_stable(self: *Map) !usize {
        var round: usize = 1;
        while (true) : (round += 1) {
            const moving = try self.run_round();
            // self.show();
            if (moving == 0) break;
        }
        return round;
    }
};

test "sample part 1 a" {
    const data: []const u8 =
        \\.....
        \\..##.
        \\..#..
        \\.....
        \\..##.
        \\.....
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.add_line(line);
    }
    // map.show();

    _ = try map.run_rounds(3);
}

test "sample part 1 b" {
    const data: []const u8 =
        \\....#..
        \\..###.#
        \\#...#.#
        \\.#...##
        \\#.###..
        \\##.#.##
        \\.#..#..
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.add_line(line);
    }
    // map.show();

    const empty = try map.run_rounds(10);
    try testing.expectEqual(@as(usize, 110), empty);
}

test "sample part 2" {
    const data: []const u8 =
        \\....#..
        \\..###.#
        \\#...#.#
        \\.#...##
        \\#.###..
        \\##.#.##
        \\.#..#..
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.add_line(line);
    }
    // map.show();

    const stable = try map.run_until_stable();
    try testing.expectEqual(@as(usize, 20), stable);
}
