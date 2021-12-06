const std = @import("std");
const assert = std.debug.assert;

const allocator = std.testing.allocator;

pub const Board = struct {
    dist: Distance,
    map: std.AutoHashMap(i32, u32),
    md: u32,
    mx: i32,
    my: i32,

    pub const Distance = enum {
        Manhattan,
        Travelled,
    };

    pub fn init(dist: Board.Distance) Board {
        var self = Board{
            .dist = dist,
            .map = std.AutoHashMap(i32, u32).init(allocator),
            .md = std.math.maxInt(u32),
            .mx = 0,
            .my = 0,
        };
        return self;
    }

    pub fn deinit(self: *Board) void {
        self.map.deinit();
    }

    pub fn trace(self: *Board, str: []const u8, first: bool) void {
        var it = std.mem.split(u8, str, ",");
        var cx: i32 = 0;
        var cy: i32 = 0;
        var cl: u32 = 0;
        while (it.next()) |what| {
            const dir = what[0];
            const len = std.fmt.parseInt(usize, what[1..], 10) catch 0;
            var dx: i32 = 0;
            dx = switch (dir) {
                'R' => 1,
                'L' => -1,
                else => 0,
            };
            var dy: i32 = 0;
            dy = switch (dir) {
                'U' => 1,
                'D' => -1,
                else => 0,
            };
            var j: usize = 0;
            while (j < len) : (j += 1) {
                cx += dx;
                cy += dy;
                cl += 1;
                const pos = cx * 10000 + cy;
                if (first) {
                    _ = self.map.put(pos, cl) catch unreachable;
                } else if (self.map.contains(pos)) {
                    const val = self.map.getEntry(pos).?.value_ptr.*;
                    const d = switch (self.dist) {
                        Distance.Manhattan => manhattan(cx, cy),
                        Distance.Travelled => travelled(val, cl),
                    };
                    if (self.md > d) {
                        self.md = d;
                        self.mx = cx;
                        self.my = cy;
                    }
                }
            }
        }
    }
};

fn manhattan(x: i32, y: i32) u32 {
    const ax = std.math.absInt(x) catch 0;
    const ay = std.math.absInt(y) catch 0;
    return @intCast(u32, ax) + @intCast(u32, ay);
}

fn travelled(v0: u32, v1: u32) u32 {
    return v0 + v1;
}

test "Manhattan - distance 6" {
    const wire0: []const u8 = "R8,U5,L5,D3";
    const wire1: []const u8 = "U7,R6,D4,L4";

    var board = Board.init(Board.Distance.Manhattan);
    defer board.deinit();

    board.trace(wire0, true);
    board.trace(wire1, false);
    assert(board.md == 6);
}

test "Manhattan - distance 159" {
    const wire0: []const u8 = "R75,D30,R83,U83,L12,D49,R71,U7,L72";
    const wire1: []const u8 = "U62,R66,U55,R34,D71,R55,D58,R83";

    var board = Board.init(Board.Distance.Manhattan);
    defer board.deinit();

    board.trace(wire0, true);
    board.trace(wire1, false);
    assert(board.md == 159);
}

test "Manhattan - distance 135" {
    const wire0: []const u8 = "R98,U47,R26,D63,R33,U87,L62,D20,R33,U53,R51";
    const wire1: []const u8 = "U98,R91,D20,R16,D67,R40,U7,R15,U6,R7";

    var board = Board.init(Board.Distance.Manhattan);
    defer board.deinit();

    board.trace(wire0, true);
    board.trace(wire1, false);
    assert(board.md == 135);
}

test "Travelled - distance 30" {
    const wire0: []const u8 = "R8,U5,L5,D3";
    const wire1: []const u8 = "U7,R6,D4,L4";

    var board = Board.init(Board.Distance.Travelled);
    defer board.deinit();

    board.trace(wire0, true);
    board.trace(wire1, false);
    assert(board.md == 30);
}

test "Travelled - distance 159" {
    const wire0: []const u8 = "R75,D30,R83,U83,L12,D49,R71,U7,L72";
    const wire1: []const u8 = "U62,R66,U55,R34,D71,R55,D58,R83";

    var board = Board.init(Board.Distance.Travelled);
    defer board.deinit();

    board.trace(wire0, true);
    board.trace(wire1, false);
    assert(board.md == 610);
}

test "Travelled - distance 135" {
    const wire0: []const u8 = "R98,U47,R26,D63,R33,U87,L62,D20,R33,U53,R51";
    const wire1: []const u8 = "U98,R91,D20,R16,D67,R40,U7,R15,U6,R7";

    var board = Board.init(Board.Distance.Travelled);
    defer board.deinit();

    board.trace(wire0, true);
    board.trace(wire1, false);
    assert(board.md == 410);
}
