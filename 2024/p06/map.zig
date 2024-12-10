const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Map = struct {
    const SIZE = 130;

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            return .{ .x = x, .y = y };
        }

        pub fn equals(self: Pos, other: Pos) bool {
            return self.x == other.x and self.y == other.y;
        }
    };

    const Dir = enum(u8) {
        U = 0b00010,
        R = 0b00100,
        D = 0b01000,
        L = 0b10000,

        fn turnRight(dir: *Dir) void {
            dir.* = switch (dir.*) {
                .U => .R,
                .R => .D,
                .D => .L,
                .L => .U,
            };
        }

        fn takeStep(dir: Dir, x: *isize, y: *isize) void {
            switch (dir) {
                .U => y.* -= 1,
                .R => x.* += 1,
                .D => y.* += 1,
                .L => x.* -= 1,
            }
        }
    };

    const Guard = struct {
        pos: Pos,
        dir: Dir,

        pub fn init(x: usize, y: usize, dir: Dir) Guard {
            return .{ .pos = Pos.init(x, y), .dir = dir };
        }
    };

    const Mark = struct {
        const MASK_OCCUPIED: u8 = 0b00001;

        // 0bxxxxxxxx
        //         |+- occupied?
        //         +-- visited moving U
        //        +--- visited moving R
        //       +---- visited moving D
        //      +----- visited moving L
        mask: u8,

        pub fn init() Mark {
            return .{ .mask = 0 };
        }

        pub fn isOccupied(self: Mark) bool {
            return self.mask & MASK_OCCUPIED > 0;
        }

        pub fn markOccupied(self: *Mark) void {
            self.mask |= MASK_OCCUPIED;
        }

        pub fn markUnoccupied(self: *Mark) void {
            self.mask &= ~MASK_OCCUPIED;
        }

        pub fn visitedGoing(self: Mark, dir: Dir) bool {
            return self.mask & @intFromEnum(dir) > 0;
        }

        pub fn visitedEver(self: Mark) bool {
            const MASK_ALL: u8 = @intFromEnum(Dir.U) | @intFromEnum(Dir.R) | @intFromEnum(Dir.D) | @intFromEnum(Dir.L);
            return self.mask & MASK_ALL > 0;
        }

        pub fn markVisitedGoing(self: *Mark, dir: Dir) void {
            self.mask |= @intFromEnum(dir);
        }

        pub fn forgetVisits(self: *Mark) void {
            self.mask &= MASK_OCCUPIED;
        }
    };

    grid: [SIZE][SIZE]Mark,
    rows: usize,
    cols: usize,
    guard: Guard,
    visited: std.AutoHashMap(Pos, void),
    attempted: std.AutoHashMap(Pos, void),

    pub fn init(allocator: Allocator) Map {
        const self = Map{
            .grid = undefined,
            .rows = 0,
            .cols = 0,
            .guard = Guard.init(0, 0, .U),
            .visited = std.AutoHashMap(Pos, void).init(allocator),
            .attempted = std.AutoHashMap(Pos, void).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.attempted.deinit();
        self.visited.deinit();
    }

    pub fn addLine(self: *Map, line: []const u8) !void {
        if (self.cols == 0) {
            self.cols = line.len;
        }
        if (self.cols != line.len) {
            return error.JaggedGrid;
        }
        const y = self.rows;
        for (line, 0..) |c, x| {
            self.grid[x][y] = Mark.init();
            switch (c) {
                '#' => self.grid[x][y].markOccupied(),
                '^' => self.updateGuard(Guard.init(x, y, .U)),
                else => {},
            }
        }
        self.rows += 1;
    }

    pub fn countVisited(self: *Map) !usize {
        if (!try self.walkAround()) {
            // was in a loop, return 0 in this case
            return 0;
        }
        var count: usize = 0;
        for (0..self.rows) |y| {
            for (0..self.cols) |x| {
                if (self.grid[x][y].visitedEver()) {
                    count += 1;
                }
            }
        }
        return count;
    }

    pub fn countPossibleObstructions(self: *Map) !usize {
        // remember all visited locations during simple walk
        self.visited.clearRetainingCapacity();
        _ = try self.walkAround();
        for (0..self.rows) |y| {
            for (0..self.cols) |x| {
                if (self.grid[x][y].visitedEver()) {
                    _ = try self.visited.getOrPut(Pos.init(x, y));
                }
            }
        }
        self.forgetAllVisits();

        self.attempted.clearRetainingCapacity();
        var count: usize = 0;
        for (0..self.rows) |y| {
            for (0..self.cols) |x| {
                if (self.grid[x][y].isOccupied()) continue; // skip occupied
                if (self.guard.pos.equals(Pos.init(x, y))) continue; // skip guard
                for (std.enums.values(Dir)) |dir| {
                    count += try self.attemptBlockingPos(x, y, dir);
                }
            }
        }
        return count;
    }

    fn updateGuard(self: *Map, guard: Guard) void {
        self.guard = guard;
        self.grid[guard.pos.x][guard.pos.y].markVisitedGoing(guard.dir);
    }

    fn validPos(self: Map, ix: isize, iy: isize) bool {
        return (ix >= 0 and ix < self.cols and iy >= 0 and iy < self.rows);
    }

    fn walkAround(self: *Map) !bool {
        const guard = self.guard;
        defer self.updateGuard(guard);
        while (true) {
            var ix: isize = @intCast(self.guard.pos.x);
            var iy: isize = @intCast(self.guard.pos.y);
            self.guard.dir.takeStep(&ix, &iy);
            if (!self.validPos(ix, iy)) {
                return true;
            }
            const nx: u8 = @intCast(ix);
            const ny: u8 = @intCast(iy);
            if (self.grid[nx][ny].isOccupied()) {
                // change direction
                self.guard.dir.turnRight();
            } else {
                // move there
                self.guard.pos = Pos.init(nx, ny);
            }
            if (self.grid[self.guard.pos.x][self.guard.pos.y].visitedGoing(self.guard.dir)) {
                // we are in a loop
                return false;
            }
            self.updateGuard(self.guard);
        }
        return false;
    }

    fn forgetAllVisits(self: *Map) void {
        for (0..self.rows) |y| {
            for (0..self.cols) |x| {
                self.grid[x][y].forgetVisits();
            }
        }
    }

    fn attemptBlockingPos(self: *Map, x: usize, y: usize, dir: Dir) !usize {
        var ix: isize = @intCast(x);
        var iy: isize = @intCast(y);
        dir.takeStep(&ix, &iy);
        if (!self.validPos(ix, iy)) return 0;
        const nx: usize = @intCast(ix);
        const ny: usize = @intCast(iy);
        if (!self.visited.contains(Pos.init(nx, ny))) return 0;
        const r = try self.attempted.getOrPut(Pos.init(nx, ny));
        if (r.found_existing) return 0;
        var blocked: usize = 0;
        self.grid[nx][ny].markOccupied();
        if (!try self.walkAround()) {
            // we managed to put guard in a loop
            blocked = 1;
        }
        self.grid[nx][ny].markUnoccupied();
        self.forgetAllVisits();
        return blocked;
    }
};

test "sample part 1" {
    const data =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#..^.....
        \\........#.
        \\#.........
        \\......#...
    ;

    var map = Map.init(testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }

    const count = try map.countVisited();
    const expected = @as(usize, 41);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\....#.....
        \\.........#
        \\..........
        \\..#.......
        \\.......#..
        \\..........
        \\.#..^.....
        \\........#.
        \\#.........
        \\......#...
    ;

    var map = Map.init(testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.addLine(line);
    }

    const count = try map.countPossibleObstructions();
    const expected = @as(usize, 6);
    try testing.expectEqual(expected, count);
}
