const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const City = struct {
    const Turn = enum {
        L,
        R,

        pub fn parse(str: []const u8) !Turn {
            for (Turns) |t| {
                if (std.mem.eql(u8, @tagName(t), str)) return t;
            }
            return error.InvalidTurn;
        }
    };
    const Turns = std.meta.tags(Turn);

    const Dir = enum {
        N,
        S,
        E,
        W,

        pub fn makeTurn(self: Dir, turn: Turn) Dir {
            return switch (self) {
                .N => switch (turn) {
                    .L => .W,
                    .R => .E,
                },
                .S => switch (turn) {
                    .L => .E,
                    .R => .W,
                },
                .E => switch (turn) {
                    .L => .N,
                    .R => .S,
                },
                .W => switch (turn) {
                    .L => .S,
                    .R => .N,
                },
            };
        }
    };

    const Move = struct {
        turn: Turn,
        steps: usize,
    };

    const Pos = struct {
        x: isize,
        y: isize,

        pub fn init(x: isize, y: isize) Pos {
            return Pos{ .x = x, .y = y };
        }
    };

    repeated: bool,
    moves: std.ArrayList(Move),
    seen: std.AutoHashMap(Pos, void),
    beg: Pos,
    cur: Pos,
    repeated_dist: usize,
    dir: Dir,

    pub fn init(allocator: Allocator, repeated: bool) City {
        var city = City{
            .repeated = repeated,
            .moves = std.ArrayList(Move).init(allocator),
            .seen = std.AutoHashMap(Pos, void).init(allocator),
            .repeated_dist = undefined,
            .beg = undefined,
            .cur = undefined,
            .dir = undefined,
        };
        city.reset();
        return city;
    }

    pub fn deinit(self: *City) void {
        self.seen.deinit();
        self.moves.deinit();
    }

    pub fn addLine(self: *City, line: []const u8) !void {
        var it = std.mem.tokenizeAny(u8, line, " ,");
        while (it.next()) |chunk| {
            var move: Move = undefined;
            move.turn = try Turn.parse(chunk[0..1]);
            move.steps = try std.fmt.parseUnsigned(usize, chunk[1..], 10);
            try self.moves.append(move);
        }
    }

    pub fn getDistanceToWalk(self: *City) !usize {
        _ = try self.walkRoute();
        return self.distance();
    }

    pub fn getFirstRepeatedDistance(self: *City) !usize {
        _ = try self.walkRoute();
        return self.repeated_dist;
    }

    fn walkRoute(self: *City) !void {
        self.reset();
        try self.visit();
        for (self.moves.items) |move| {
            self.dir = self.dir.makeTurn(move.turn);
            switch (self.dir) {
                .N => for (0..move.steps) |_| {
                    self.cur.y -= 1;
                    try self.visit();
                },
                .S => for (0..move.steps) |_| {
                    self.cur.y += 1;
                    try self.visit();
                },
                .E => for (0..move.steps) |_| {
                    self.cur.x += 1;
                    try self.visit();
                },
                .W => for (0..move.steps) |_| {
                    self.cur.x -= 1;
                    try self.visit();
                },
            }
        }
    }

    fn reset(self: *City) void {
        self.beg = Pos.init(0, 0);
        self.cur = Pos.init(0, 0);
        self.repeated_dist = std.math.maxInt(usize);
        self.dir = .N;
        self.seen.clearRetainingCapacity();
    }

    fn distance(self: *City) usize {
        var dist: isize = 0;
        dist += if (self.cur.x > self.beg.x) self.cur.x - self.beg.x else self.beg.x - self.cur.x;
        dist += if (self.cur.y > self.beg.y) self.cur.y - self.beg.y else self.beg.y - self.cur.y;
        return @intCast(dist);
    }

    fn visit(self: *City) !void {
        const r = try self.seen.getOrPut(self.cur);
        if (!r.found_existing) return;
        if (self.repeated_dist != std.math.maxInt(usize)) return;
        self.repeated_dist = self.distance();
    }
};

test "sample part 1 case A" {
    const data =
        \\R2, L3
    ;

    var city = City.init(std.testing.allocator, false);
    defer city.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try city.addLine(line);
    }
    // city.show();

    const distance = try city.getDistanceToWalk();
    const expected = @as(usize, 5);
    try testing.expectEqual(expected, distance);
}

test "sample part 1 case B" {
    const data =
        \\R2, R2, R2
    ;

    var city = City.init(std.testing.allocator, false);
    defer city.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try city.addLine(line);
    }
    // city.show();

    const distance = try city.getDistanceToWalk();
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, distance);
}

test "sample part 1 case C" {
    const data =
        \\R5, L5, R5, R3
    ;

    var city = City.init(std.testing.allocator, false);
    defer city.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try city.addLine(line);
    }
    // city.show();

    const distance = try city.getDistanceToWalk();
    const expected = @as(usize, 12);
    try testing.expectEqual(expected, distance);
}

test "sample part 2" {
    const data =
        \\R8, R4, R4, R8
    ;

    var city = City.init(std.testing.allocator, false);
    defer city.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try city.addLine(line);
    }
    // city.show();

    const distance = try city.getFirstRepeatedDistance();
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, distance);
}
