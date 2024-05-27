const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Board = struct {
    const Pos = Math.Vector(usize, 2);
    const WIRES = 2;
    const OFFSET = 5000;

    const Dir = enum(u8) {
        U = 'U',
        D = 'D',
        L = 'L',
        R = 'R',

        pub fn parse(ch: u8) !Dir {
            for (Dirs) |d| {
                if (@intFromEnum(d) == ch) return d;
            }
            return error.InvalidDir;
        }
    };
    const Dirs = std.meta.tags(Dir);

    const Spec = struct {
        dir: Dir,
        length: usize,

        pub fn init(str: []const u8) !Spec {
            return .{
                .dir = try Dir.parse(str[0]),
                .length = try std.fmt.parseUnsigned(usize, str[1..], 10),
            };
        }
    };

    const Path = struct {
        wire: usize,
        walked: usize,

        pub fn init(wire: usize, walked: usize) Path {
            return .{ .wire = wire, .walked = walked };
        }
    };

    specs: [WIRES]std.ArrayList(Spec),
    count: usize,
    seen: std.AutoHashMap(Pos, Path),
    closest_distance: usize,
    closest_walked: usize,

    pub fn init(allocator: Allocator) Board {
        var self = Board{
            .specs = undefined,
            .count = 0,
            .seen = std.AutoHashMap(Pos, Path).init(allocator),
            .closest_distance = std.math.maxInt(usize),
            .closest_walked = std.math.maxInt(usize),
        };
        for (0..WIRES) |wire| {
            self.specs[wire] = std.ArrayList(Spec).init(allocator);
        }
        return self;
    }

    pub fn deinit(self: *Board) void {
        self.seen.deinit();
        for (0..WIRES) |wire| {
            self.specs[wire].deinit();
        }
    }

    pub fn addLine(self: *Board, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ',');
        while (it.next()) |chunk| {
            try self.specs[self.count].append(try Spec.init(chunk));
        }
        self.count += 1;
    }

    pub fn getDistanceToClosestIntersection(self: *Board) !usize {
        try self.walkSpecs();
        return self.closest_distance;
    }

    pub fn getWalkedToClosestIntersection(self: *Board) !usize {
        try self.walkSpecs();
        return self.closest_walked;
    }

    fn walkSpecs(self: *Board) !void {
        self.seen.clearRetainingCapacity();
        self.closest_distance = std.math.maxInt(usize);
        self.closest_walked = std.math.maxInt(usize);
        const start = Pos.copy(&[_]usize{ OFFSET, OFFSET });
        for (0..WIRES) |wire| {
            var pos = start;
            var walked: usize = 0;
            for (self.specs[wire].items) |spec| {
                for (0..spec.length) |_| {
                    switch (spec.dir) {
                        .U => pos.v[1] -= 1,
                        .D => pos.v[1] += 1,
                        .L => pos.v[0] -= 1,
                        .R => pos.v[0] += 1,
                    }
                    walked += 1;

                    var crossing = false;
                    var total_walked = walked;
                    const r = try self.seen.getOrPut(pos);
                    if (r.found_existing and r.value_ptr.wire != wire) {
                        crossing = true;
                        total_walked += r.value_ptr.walked;
                    }
                    r.value_ptr.* = Path.init(wire, walked);
                    if (!crossing) continue;
                    // std.debug.print("Crossing at {}\n", .{pos});

                    if (self.closest_walked > total_walked)
                        self.closest_walked = total_walked;

                    const distance = start.manhattanDist(pos);
                    if (self.closest_distance > distance)
                        self.closest_distance = distance;
                }
            }
        }
    }
};

test "sample part 1 case A" {
    const data =
        \\R8,U5,L5,D3
        \\U7,R6,D4,L4
    ;

    var board = Board.init(std.testing.allocator);
    defer board.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try board.addLine(line);
    }

    const closest = try board.getDistanceToClosestIntersection();
    const expected = @as(usize, 6);
    try testing.expectEqual(expected, closest);
}

test "sample part 1 case B" {
    const data =
        \\R75,D30,R83,U83,L12,D49,R71,U7,L72
        \\U62,R66,U55,R34,D71,R55,D58,R83
    ;

    var board = Board.init(std.testing.allocator);
    defer board.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try board.addLine(line);
    }

    const closest = try board.getDistanceToClosestIntersection();
    const expected = @as(usize, 159);
    try testing.expectEqual(expected, closest);
}

test "sample part 1 case C" {
    const data =
        \\R98,U47,R26,D63,R33,U87,L62,D20,R33,U53,R51
        \\U98,R91,D20,R16,D67,R40,U7,R15,U6,R7
    ;

    var board = Board.init(std.testing.allocator);
    defer board.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try board.addLine(line);
    }

    const closest = try board.getDistanceToClosestIntersection();
    const expected = @as(usize, 135);
    try testing.expectEqual(expected, closest);
}

test "sample part 2 case A" {
    const data =
        \\R8,U5,L5,D3
        \\U7,R6,D4,L4
    ;

    var board = Board.init(std.testing.allocator);
    defer board.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try board.addLine(line);
    }

    const closest = try board.getWalkedToClosestIntersection();
    const expected = @as(usize, 30);
    try testing.expectEqual(expected, closest);
}

test "sample part 2 case B" {
    const data =
        \\R75,D30,R83,U83,L12,D49,R71,U7,L72
        \\U62,R66,U55,R34,D71,R55,D58,R83
    ;

    var board = Board.init(std.testing.allocator);
    defer board.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try board.addLine(line);
    }

    const closest = try board.getWalkedToClosestIntersection();
    const expected = @as(usize, 610);
    try testing.expectEqual(expected, closest);
}

test "sample part 2 case C" {
    const data =
        \\R98,U47,R26,D63,R33,U87,L62,D20,R33,U53,R51
        \\U98,R91,D20,R16,D67,R40,U7,R15,U6,R7
    ;

    var board = Board.init(std.testing.allocator);
    defer board.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try board.addLine(line);
    }

    const closest = try board.getWalkedToClosestIntersection();
    const expected = @as(usize, 410);
    try testing.expectEqual(expected, closest);
}
