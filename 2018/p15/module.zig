const std = @import("std");
const testing = std.testing;
const Grids = @import("./util/grid.zig");
const Math = @import("./util/math.zig").Math;
const DEQueue = @import("./util/queue.zig").DoubleEndedQueue;

const Allocator = std.mem.Allocator;

pub const Game = struct {
    const Pos = Math.Vector(usize, 2);
    const Grid = Grids.DenseGrid(Kind);
    const Queue = DEQueue(Pos);

    const INFINITY = std.math.maxInt(usize);
    const ATTACK_POWER = 3;
    const HIT_POINTS = 200;

    const Kind = enum(u8) {
        wall = '#',
        free = '.',
        goblin = 'G',
        elf = 'E',

        pub fn format(
            kind: Kind,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("{c}", .{@intFromEnum(kind)});
        }
    };

    const Team = enum(u8) {
        goblin = 'G',
        elf = 'E',
    };

    const Dx = [_]isize{ -1, 1, 0, 0 };
    const Dy = [_]isize{ 0, 0, -1, 1 };

    const Unit = struct {
        team: Team,
        pos: Pos,
        attack_power: usize,
        hit_points: usize,

        pub fn init(team: Team, x: usize, y: usize) Unit {
            return .{
                .team = team,
                .pos = Pos.copy(&[_]usize{ x, y }),
                .attack_power = ATTACK_POWER,
                .hit_points = HIT_POINTS,
            };
        }

        pub fn is_alive(self: Unit) bool {
            return self.hit_points > 0;
        }

        pub fn is_enemy(self: Unit, other: Unit) bool {
            return self.team != other.team;
        }

        pub fn receiveDamage(self: *Unit, other: Unit) void {
            self.hit_points -= other.attack_power;
        }

        pub fn lessThanByPos(_: void, l: Unit, r: Unit) bool {
            // sort by reading order
            return Pos.lessThan({}, l.pos, r.pos);
        }

        pub fn lessThanByHitPos(_: void, l: *Unit, r: *Unit) bool {
            // sort by hit_points, then reading order
            const ho = std.math.order(l.hit_points, r.hit_points);
            if (ho != .eq) return ho == .lt;
            return Pos.lessThan({}, l.pos, r.pos);
        }
    };

    allocator: Allocator,
    grid: Grid,
    units: std.ArrayList(Unit),
    saved: bool,
    saved_grid: Grid,
    saved_units: std.ArrayList(Unit),
    elf_beg: usize,
    elf_end: usize,
    goblin_beg: usize,
    goblin_end: usize,

    // internal stuff
    queue: Queue,
    dist: std.AutoHashMap(Pos, usize),
    targets: std.ArrayList(Pos),
    nearest: std.ArrayList(Pos),
    neighbor_dists: std.ArrayList(usize),
    possible: std.ArrayList(Pos),
    adjacent: std.ArrayList(*Unit),

    pub fn init(allocator: Allocator) !Game {
        return .{
            .allocator = allocator,
            .grid = Grid.init(allocator, .free),
            .units = std.ArrayList(Unit).init(allocator),
            .saved = false,
            .saved_grid = Grid.init(allocator, .free),
            .saved_units = std.ArrayList(Unit).init(allocator),
            .elf_beg = 0,
            .elf_end = 0,
            .goblin_beg = 0,
            .goblin_end = 0,
            .queue = Queue.init(allocator),
            .dist = std.AutoHashMap(Pos, usize).init(allocator),
            .targets = std.ArrayList(Pos).init(allocator),
            .nearest = std.ArrayList(Pos).init(allocator),
            .neighbor_dists = std.ArrayList(usize).init(allocator),
            .possible = std.ArrayList(Pos).init(allocator),
            .adjacent = std.ArrayList(*Unit).init(allocator),
        };
    }

    pub fn deinit(self: *Game) void {
        self.adjacent.deinit();
        self.possible.deinit();
        self.neighbor_dists.deinit();
        self.nearest.deinit();
        self.targets.deinit();
        self.dist.deinit();
        self.queue.deinit();
        self.saved_units.deinit();
        self.saved_grid.deinit();
        self.units.deinit();
        self.grid.deinit();
    }

    pub fn addLine(self: *Game, line: []const u8) !void {
        try self.grid.ensureCols(line.len);
        const y = self.grid.rows();
        try self.grid.ensureExtraRow();
        for (line, 0..) |c, x| {
            switch (c) {
                '#' => try self.grid.set(x, y, .wall),
                '.' => try self.grid.set(x, y, .free),
                'G' => {
                    try self.grid.set(x, y, .goblin);
                    try self.units.append(Unit.init(.goblin, x, y));
                    self.goblin_beg += 1;
                },
                'E' => {
                    try self.grid.set(x, y, .elf);
                    try self.units.append(Unit.init(.elf, x, y));
                    self.elf_beg += 1;
                },
                else => return error.InvalidChar,
            }
        }
    }

    pub fn show(self: *Game) !void {
        std.debug.print("Game on a {}x{} grid\n", .{
            self.grid.rows(),
            self.grid.cols(),
        });
        for (0..self.grid.rows()) |y| {
            for (0..self.grid.cols()) |x| {
                std.debug.print("{}", .{self.grid.get(x, y)});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn playGame(self: *Game, elf_attack_power: usize) !usize {
        try self.resetWithPower(elf_attack_power);
        var num_round: usize = 0;
        var outcome: usize = 0;
        while (true) {
            const complete = try self.playRound();
            num_round += 1;
            // std.debug.print("After {} rounds:\n", .{num_round});
            // try self.show();

            self.elf_end = 0;
            self.goblin_end = 0;
            for (self.units.items) |u| {
                if (!u.is_alive()) continue;
                if (u.team == .elf) {
                    self.elf_end += 1;
                } else {
                    self.goblin_end += 1;
                }
            }

            if (self.elf_end == 0 or self.goblin_end == 0) {
                var all_hp: usize = 0;
                var rounds = num_round;
                if (!complete) rounds -= 1;
                for (self.units.items) |u| {
                    if (!u.is_alive()) continue;
                    all_hp += u.hit_points;
                }
                outcome = all_hp * rounds;
                break;
            }
        }
        return outcome;
    }

    pub fn findLowestPower(self: *Game, highest_elf_power: usize) !usize {
        var lowest_power: usize = INFINITY;
        var lowest_outcome: usize = INFINITY;
        var lo: usize = ATTACK_POWER + 1;
        var hi: usize = highest_elf_power;
        while (lo < hi) {
            const power: usize = (lo + hi) / 2;
            const outcome = try self.playGame(power);
            if (self.allElvesSurvived()) {
                hi = power - 1;
                if (lowest_power > power) {
                    lowest_power = power;
                    lowest_outcome = outcome;
                }
            } else {
                lo = power + 1;
            }
        }
        return lowest_outcome;
    }

    fn copyGrid(src: Grid, tgt: *Grid) !void {
        try tgt.*.ensureCols(src.cols());
        for (0..src.rows()) |y| {
            try tgt.*.ensureExtraRow();
            for (0..src.cols()) |x| {
                try tgt.*.set(x, y, src.get(x, y));
            }
        }
    }

    fn copyUnits(src: std.ArrayList(Unit), tgt: *std.ArrayList(Unit)) !void {
        tgt.*.clearRetainingCapacity();
        for (src.items) |u| {
            try tgt.*.append(u);
        }
    }

    fn resetWithPower(self: *Game, elf_attack_power: usize) !void {
        if (!self.saved) {
            self.saved = true;
            try copyGrid(self.grid, &self.saved_grid);
            try copyUnits(self.units, &self.saved_units);
        } else {
            try copyGrid(self.saved_grid, &self.grid);
            try copyUnits(self.saved_units, &self.units);
        }
        const power: usize = if (elf_attack_power == 0) ATTACK_POWER else elf_attack_power;
        for (self.units.items) |*u| {
            if (u.team != .elf) continue;
            u.attack_power = power;
        }
    }

    fn positionTakenByUnit(self: Game, p: Pos) bool {
        const k = self.grid.get(p.v[0], p.v[1]);
        return k == .elf or k == .goblin;
    }

    fn findAdjacentEnemies(self: *Game, unit: Unit) !usize {
        // count alive enemies and find adjacent units
        var alive_enemies: usize = 0;
        self.adjacent.clearRetainingCapacity();
        for (self.units.items) |*u| {
            if (!u.is_alive()) continue;
            if (!u.is_enemy(unit)) continue;
            alive_enemies += 1;
            if (u.pos.manhattanDist(unit.pos) != 1) continue;
            try self.adjacent.append(u);
        }
        return alive_enemies;
    }

    fn computeDistancesFrom(self: *Game, src: Pos) !void {
        // initialize all distances to infinity
        self.dist.clearRetainingCapacity();
        for (0..self.grid.rows()) |y| {
            for (0..self.grid.cols()) |x| {
                try self.dist.put(Pos.copy(&[_]usize{ x, y }), INFINITY);
            }
        }

        // start with src, whose distance is zero
        self.queue.clearRetainingCapacity();
        try self.queue.append(src);
        try self.dist.put(src, 0);

        // assign each point its real distance
        while (!self.queue.empty()) {
            const cur = try self.queue.pop();
            const ndist = self.dist.get(cur).? + 1;
            for (&Dx, &Dy) |dx, dy| {
                var ix: isize = @intCast(cur.v[0]);
                var iy: isize = @intCast(cur.v[1]);
                ix += dx;
                iy += dy;
                const nx: usize = @intCast(ix);
                const ny: usize = @intCast(iy);
                if (self.grid.get(nx, ny) == .wall) continue;
                const npos = Pos.copy(&[_]usize{ nx, ny });
                if (self.positionTakenByUnit(npos)) continue;
                if (self.dist.get(npos)) |d| {
                    if (d != INFINITY and d <= ndist) continue;
                    try self.dist.put(npos, ndist);
                    try self.queue.append(npos);
                }
            }
        }
    }

    fn changeUnitPosition(self: *Game, unit: *Unit, pos: Pos) !void {
        const kind = self.grid.get(unit.pos.v[0], unit.pos.v[1]);
        try self.grid.set(unit.pos.v[0], unit.pos.v[1], .free);
        unit.pos = pos;
        try self.grid.set(unit.pos.v[0], unit.pos.v[1], kind);
    }

    fn killUnit(self: *Game, unit: *Unit) !void {
        unit.*.hit_points = 0;
        try self.grid.set(unit.pos.v[0], unit.pos.v[1], .free);
    }

    fn moveUnit(self: *Game, unit: *Unit) !void {
        // set up distance map for the unit
        try self.computeDistancesFrom(unit.pos);

        // gather possible targets (positions in range of an enemy)
        self.targets.clearRetainingCapacity();
        for (self.units.items) |u| {
            if (!u.is_alive()) continue;
            if (!unit.is_enemy(u)) continue;
            for (&Dx, &Dy) |dx, dy| {
                var ix: isize = @intCast(u.pos.v[0]);
                var iy: isize = @intCast(u.pos.v[1]);
                ix += dx;
                iy += dy;
                const nx: usize = @intCast(ix);
                const ny: usize = @intCast(iy);
                if (self.grid.get(nx, ny) == .wall) continue;
                const npos = Pos.copy(&[_]usize{ nx, ny });
                if (self.positionTakenByUnit(npos)) continue;
                try self.targets.append(npos);
            }
        }

        // find the distance to the closest of these targets
        var nearest_dist: usize = INFINITY;
        for (self.targets.items) |t| {
            if (self.dist.get(t)) |d| {
                if (d == INFINITY) continue;
                if (nearest_dist > d) {
                    nearest_dist = d;
                }
            }
        }

        // no closest distance, cannot move
        if (nearest_dist == INFINITY) return;

        // find all the targets that lie at this distance
        self.nearest.clearRetainingCapacity();
        for (self.targets.items) |t| {
            if (self.dist.get(t)) |d| {
                if (d == nearest_dist) {
                    try self.nearest.append(t);
                }
            }
        }

        // no nearest target, cannot move
        if (self.nearest.items.len == 0) return;

        // sort and choose "first" target
        std.sort.heap(Pos, self.nearest.items, {}, Pos.lessThan);
        const chosen = self.nearest.items[0];

        // compute distances again, but now with the chosen point as the start
        try self.computeDistancesFrom(chosen);

        // get distances from all possible neighbors, where the unit could move
        self.neighbor_dists.clearRetainingCapacity();
        for (&Dx, &Dy) |dx, dy| {
            var ix: isize = @intCast(unit.pos.v[0]);
            var iy: isize = @intCast(unit.pos.v[1]);
            ix += dx;
            iy += dy;
            const nx: usize = @intCast(ix);
            const ny: usize = @intCast(iy);
            const npos = Pos.copy(&[_]usize{ nx, ny });
            if (self.dist.get(npos)) |d| {
                try self.neighbor_dists.append(d);
            }
        }

        // get minimum distance among neighbors
        var min_dist: usize = INFINITY;
        for (self.neighbor_dists.items) |d| {
            if (d == INFINITY) continue;
            if (min_dist > d) {
                min_dist = d;
            }
        }

        // no minimum distance, cannot move
        if (min_dist == INFINITY) return;

        // collect possible neighbours that lie at this distance
        self.possible.clearRetainingCapacity();
        for (&Dx, &Dy) |dx, dy| {
            var ix: isize = @intCast(unit.pos.v[0]);
            var iy: isize = @intCast(unit.pos.v[1]);
            ix += dx;
            iy += dy;
            const nx: usize = @intCast(ix);
            const ny: usize = @intCast(iy);
            const npos = Pos.copy(&[_]usize{ nx, ny });
            if (self.dist.get(npos)) |d| {
                if (d == min_dist) {
                    try self.possible.append(npos);
                }
            }
        }

        // no possible neighbors, cannot move
        if (self.possible.items.len == 0) return;

        // sort and choose "first" neighbor
        std.sort.heap(Pos, self.possible.items, {}, Pos.lessThan);

        // we have finally determined where to move
        try self.changeUnitPosition(unit, self.possible.items[0]);
    }

    fn playRound(self: *Game) !bool {
        // sort units according to their position ("reading order")
        std.sort.heap(Unit, self.units.items, {}, Unit.lessThanByPos);

        for (self.units.items) |*u| {
            // skip dead units
            if (!u.is_alive()) continue;

            self.adjacent.clearRetainingCapacity();
            const alive_enemies = try self.findAdjacentEnemies(u.*);
            if (alive_enemies == 0) return false;

            if (self.adjacent.items.len == 0) {
                // if there are no adjacent enemies, move and recompute adjacent enemies
                try self.moveUnit(u);
                _ = try self.findAdjacentEnemies(u.*);
            }

            // if there are adjacent enemies, sort and attack "first" enemy
            if (self.adjacent.items.len != 0) {
                std.sort.heap(*Unit, self.adjacent.items, {}, Unit.lessThanByHitPos);
                const attacked = self.adjacent.items[0];
                if (attacked.*.hit_points <= u.attack_power) {
                    try self.killUnit(attacked);
                } else {
                    attacked.*.receiveDamage(u.*);
                }
            }
        }
        return true;
    }

    fn allElvesSurvived(self: Game) bool {
        return self.elf_beg == self.elf_end;
    }
};

test "sample part 1 part A" {
    const data =
        \\#######
        \\#.G...#
        \\#...EG#
        \\#.#.#G#
        \\#..G#E#
        \\#.....#
        \\#######
    ;

    var game = try Game.init(testing.allocator);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }
    const outcome = try game.playGame(0);
    const expected = @as(usize, 27730);
    try testing.expectEqual(expected, outcome);
}

test "sample part 1 part B" {
    const data =
        \\#######
        \\#G..#E#
        \\#E#E.E#
        \\#G.##.#
        \\#...#E#
        \\#...E.#
        \\#######
    ;

    var game = try Game.init(testing.allocator);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }
    const outcome = try game.playGame(0);
    const expected = @as(usize, 36334);
    try testing.expectEqual(expected, outcome);
}

test "sample part 1 part C" {
    const data =
        \\#######
        \\#E..EG#
        \\#.#G.E#
        \\#E.##E#
        \\#G..#.#
        \\#..E#.#
        \\#######
    ;

    var game = try Game.init(testing.allocator);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }
    const outcome = try game.playGame(0);
    const expected = @as(usize, 39514);
    try testing.expectEqual(expected, outcome);
}

test "sample part 1 part D" {
    const data =
        \\#######
        \\#E.G#.#
        \\#.#G..#
        \\#G.#.G#
        \\#G..#.#
        \\#...E.#
        \\#######
    ;

    var game = try Game.init(testing.allocator);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }
    const outcome = try game.playGame(0);
    const expected = @as(usize, 27755);
    try testing.expectEqual(expected, outcome);
}

test "sample part 1 part E" {
    const data =
        \\#######
        \\#.E...#
        \\#.#..G#
        \\#.###.#
        \\#E#G#G#
        \\#...#G#
        \\#######
    ;

    var game = try Game.init(testing.allocator);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }
    const outcome = try game.playGame(0);
    const expected = @as(usize, 28944);
    try testing.expectEqual(expected, outcome);
}

test "sample part 1 part F" {
    const data =
        \\#########
        \\#G......#
        \\#.E.#...#
        \\#..##..G#
        \\#...##..#
        \\#...#...#
        \\#.G...G.#
        \\#.....G.#
        \\#########
    ;

    var game = try Game.init(testing.allocator);
    defer game.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try game.addLine(line);
    }
    const outcome = try game.playGame(0);
    const expected = @as(usize, 18740);
    try testing.expectEqual(expected, outcome);
}
