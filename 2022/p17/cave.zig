const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Cave = struct {
    const Rock = enum(u8) {
        Minus,
        Plus,
        L,
        I,
        Square,
    };
    const ROCKS = [5]Rock{ .Minus, .Plus, .L, .I, .Square };
    const WIDTH = 7;
    const PAD_X = 2;
    const PAD_Y = 3;

    const Action = enum(u8) {
        L = '<',
        R = '>',
        D = 'v',
        N = '.',

        pub fn parse(c: u8) Action {
            return switch (c) {
                '<' => .L,
                '>' => .R,
                else => unreachable,
            };
        }
    };

    const Pos = struct {
        x: isize,
        y: isize,

        pub fn init(x: isize, y: isize) Pos {
            return Pos{.x = x, .y = y};
        }
    };

    const Cell = enum(u8) {
        Wall  = '^',
        Empty = '.',
        Falling = '@',
        Settled = '#',
    };

    const State = struct {
        rock: usize,
        action: usize,
        dists: [WIDTH]usize,

        pub fn init(rock: usize, action: usize) State {
            return State{.rock = rock, .action = action, .dists = undefined};
        }
    };

    const Memory = struct {
        cycle: usize,
        top: isize,

        pub fn init(cycle: usize, top: isize) Memory {
            return Memory{.cycle = cycle, .top = top};
        }
    };

    allocator: Allocator,
    grid: std.AutoHashMap(Pos, Cell),
    actions: std.ArrayList(Action),
    pos: Pos,
    state: Cell,
    top: isize,
    action_pos: usize,
    rock_pos: usize,
    min: Pos,
    max: Pos,
    seen: std.AutoHashMap(State, Memory),

    pub fn init(allocator: Allocator) !Cave {
        var self = Cave{
            .allocator = allocator,
            .grid = std.AutoHashMap(Pos, Cell).init(allocator),
            .actions = std.ArrayList(Action).init(allocator),
            .pos = undefined,
            .state = undefined,
            .top = -1,
            .action_pos = 0,
            .rock_pos = 0,
            .min = Pos.init(std.math.maxInt(isize), std.math.maxInt(isize)),
            .max = Pos.init(std.math.minInt(isize), std.math.minInt(isize)),
            .seen = std.AutoHashMap(State, Memory).init(allocator),
        };

        // draw minimum chamber
        var y: isize = -1;
        while (y <= PAD_Y) : (y += 1) {
            var x: isize = -1;
            while (x <= WIDTH) : (x += 1) {
                const pos = Pos.init(x, y);
                try self.set_pos(pos, .Empty);
            }
        }

        return self;
    }

    pub fn deinit(self: *Cave) void {
        self.seen.deinit();
        self.grid.deinit();
        self.actions.deinit();
    }

    fn get_pos(self: Cave, pos: Pos) Cell {
        var cell = self.grid.get(pos) orelse .Empty;
        if (pos.y < 0) cell = .Wall;
        if (pos.x < 0) cell = .Wall;
        if (pos.x == WIDTH) cell = .Wall;
        return cell;
    }

    fn set_pos(self: *Cave, pos: Pos, what: Cell) !void {
        try self.grid.put(pos, what);
        if (self.min.x > pos.x) self.min.x = pos.x;
        if (self.max.x < pos.x) self.max.x = pos.x;
        if (self.min.y > pos.y) self.min.y = pos.y;
        if (self.max.y < pos.y) self.max.y = pos.y;
    }

    fn add_action(self: *Cave, c: u8) !void {
        const action = Action.parse(c);
        try self.actions.append(action);
    }

    fn mark_rock(self: *Cave, pos: Pos, data: []const u8, mark: Cell) !void {
        var y: isize = 0;
        var it = std.mem.split(u8, data, "\n");
        while (it.next()) |line| : (y += 1) {
            for (line) |c, x| {
                const p = Pos.init(pos.x + @intCast(isize, x), pos.y + y);
                if (mark == .Settled and self.top < p.y) self.top = p.y;

                if (c != '#') continue;
                try self.set_pos(p, mark);
            }
        }
    }

    fn can_move(self: *Cave, pos: Pos, data: []const u8) bool {
        var y: isize = 0;
        var it = std.mem.split(u8, data, "\n");
        while (it.next()) |line| : (y += 1) {
            for (line) |c, x| {
                if (c != '#') continue;
                const p = Pos.init(pos.x + @intCast(isize, x), pos.y + y);
                const cur = self.get_pos(p);
                if (cur == .Empty) continue;
                return false;
            }
        }
        return true;
    }

    fn draw_rock(self: *Cave, rock: Rock, action: Action) !bool {
        if (self.state == .Settled) return false;

        const data: []const u8 = switch (rock) {
            .Minus =>
            \\####
            ,
            .Plus =>
            \\.#.
            \\###
            \\.#.
            ,
            .L =>
            \\###
            \\..#
            \\..#
            ,
            .I =>
            \\#
            \\#
            \\#
            \\#

            ,
            .Square =>
            \\##
            \\##
            ,
        };

        const pos = switch (action) {
            .L => Pos.init(self.pos.x - 1, self.pos.y),
            .R => Pos.init(self.pos.x + 1, self.pos.y),
            .D => Pos.init(self.pos.x, self.pos.y - 1),
            .N => Pos.init(self.pos.x, self.pos.y),
        };

        try self.mark_rock(self.pos, data, Cell.Empty);
        const can = self.can_move(pos, data);
        if (can) {
            try self.mark_rock(pos, data, Cell.Falling);
            self.pos = pos;
            return true;
        }
        var mark = Cell.Falling;
        if (action == .D) {
            self.state = .Settled;
            mark = Cell.Settled;
        }
        try self.mark_rock(self.pos, data, mark);
        return false;
    }

    fn move_rock(self: *Cave, rock: Rock) !void {
        while (true) {
            const action = self.actions.items[self.action_pos];
            self.action_pos += 1;
            if (self.action_pos >= self.actions.items.len) {
                self.action_pos = 0;
            }

            _ = try self.draw_rock(rock, action);
            if (!try self.draw_rock(rock, .D)) break;
        }
    }

    fn check_state(self: *Cave, current: usize, total: usize, state: *State) !isize {
        var p: usize = 0;
        while (p < WIDTH) : (p += 1) {
            var h: usize = 0;
            while (true) : (h += 1) {
                if (h >= self.top) break;
                const pos = Pos.init(@intCast(isize, p), self.top - @intCast(isize, h));
                if (self.get_pos(pos) != .Empty) break;
            }
            state.*.dists[p] = h;
        }
        var result = try self.seen.getOrPut(state.*);
        if (!result.found_existing) {
            result.value_ptr.* = Memory.init(current, self.top);
        } else {
            const previous = result.value_ptr.*;
            const period = current - previous.cycle;
            const remaining = total - current;
            const repeats = remaining / period;
            const modulo = remaining % period;
            const delta = self.top - previous.top;
            const extra = @intCast(isize, repeats) * delta;
            const predicted = self.top + extra;
            if (modulo == 0) return predicted;
        }
        return 0;
    }

    fn cycle_rock(self: *Cave, current: usize, total: usize) !isize {
        var state = State.init(self.rock_pos, self.action_pos);
        const predicted = try self.check_state(current, total, &state);
        if (predicted > 0) return predicted;

        const rock = ROCKS[self.rock_pos];
        self.rock_pos += 1;
        if (self.rock_pos >= ROCKS.len) {
            self.rock_pos = 0;
        }

        self.pos = Pos.init(PAD_X, self.top + PAD_Y + 1);
        self.state = .Falling;
        _ = try self.draw_rock(rock, .N);
        try self.move_rock(rock);
        return 0;
    }

    pub fn add_line(self: *Cave, line: []const u8) !void {
        for (line) |c| {
            try self.add_action(c);
        }
    }

    pub fn show(self: Cave) void {
        std.debug.print("----------\n", .{});
        for (self.actions.items) |a| {
            std.debug.print("{c}", .{@enumToInt(a)});
        }
        std.debug.print("\n", .{});
        var p: usize = 0;
        while (p < self.action_pos) : (p += 1) {
            std.debug.print(" ", .{});
        }
        std.debug.print("#\n", .{});
        var y: isize = self.max.y;
        var gonzo: usize = 0;
        while (y >= self.min.y) : (y -= 1) {
            var x: isize = self.min.x;
            while (x <= self.max.x) : (x += 1) {
                const pos = Pos.init(x, y);
                const cell = self.get_pos(pos);
                std.debug.print("{c}", .{@enumToInt(cell)});
            }
            std.debug.print("\n", .{});
            gonzo += 1;
            if (gonzo > 10) break;
        }
    }

    pub fn run_cycles(self: *Cave, cycles: usize) !usize {
        var count: usize = 0;
        while (count < cycles) : (count += 1) {
            const predicted = try self.cycle_rock(count, cycles);
            if (predicted > 0) {
                self.top = predicted;
                break;
            }
        }

        const height = @intCast(usize, self.top + 1);
        return height;
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\>>><<><>><<<>><>>><<<>>><<<><<<>><>><<>>
    ;

    var cave = try Cave.init(std.testing.allocator);
    defer cave.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cave.add_line(line);
    }

    const height = try cave.run_cycles(2022);
    try testing.expectEqual(@as(usize, 3068), height);
}

test "sample part 2" {
    const data: []const u8 =
        \\>>><<><>><<<>><>>><<<>>><<<><<<>><>><<>>
    ;

    var cave = try Cave.init(std.testing.allocator);
    defer cave.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cave.add_line(line);
    }

    const height = try cave.run_cycles(1000000000000);
    try testing.expectEqual(@as(usize, 1514285714288), height);
}
