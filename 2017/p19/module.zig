const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;
const Grid = @import("./util/grid.zig").Grid;

const Allocator = std.mem.Allocator;

pub const Routing = struct {
    const Pos = Math.Vector(usize, 2);
    const Data = Grid(u8);
    const EMPTY = ' ';
    const JUNCTURE = '+';
    const ENTRY = '|';

    const Dir = enum {
        N,
        S,
        E,
        W,

        pub fn isVertical(self: Dir) bool {
            return switch (self) {
                .N, .S => true,
                else => false,
            };
        }

        pub fn isHorizontal(self: Dir) bool {
            return switch (self) {
                .E, .W => true,
                else => false,
            };
        }

        pub fn move(self: Dir, pos: *Pos) void {
            switch (self) {
                .N => pos.v[1] -= 1,
                .S => pos.v[1] += 1,
                .E => pos.v[0] += 1,
                .W => pos.v[0] -= 1,
            }
        }
    };

    const Delta = struct {
        dx: isize,
        dy: isize,
        dir: Dir,

        pub fn valid(self: Delta, dir: Dir) bool {
            if (dir.isVertical() and self.dy != 0) return false;
            if (dir.isHorizontal() and self.dx != 0) return false;
            return true;
        }
    };
    const Deltas = [_]Delta{
        Delta{ .dx = -1, .dy = 0, .dir = .W },
        Delta{ .dx = 1, .dy = 0, .dir = .E },
        Delta{ .dx = 0, .dy = -1, .dir = .N },
        Delta{ .dx = 0, .dy = 1, .dir = .S },
    };

    grid: Data,
    start: Pos,
    dir: Dir,
    buf: [100]u8,
    len: usize,
    count: usize,

    pub fn init(allocator: Allocator) Routing {
        return .{
            .grid = Data.init(allocator, EMPTY),
            .start = Pos.init(),
            .dir = .S,
            .buf = undefined,
            .len = 0,
            .count = 0,
        };
    }

    pub fn deinit(self: *Routing) void {
        self.grid.deinit();
    }

    pub fn addLine(self: *Routing, line: []const u8) !void {
        try self.grid.ensureCols(line.len);
        try self.grid.ensureExtraRow();
        const y = self.grid.rows();
        for (line, 0..) |c, x| {
            try self.grid.set(x, y, c);
            if (c == ENTRY and y == 0) {
                self.start = Pos.copy(&[_]usize{ x, y });
            }
        }
    }

    pub fn show(self: Routing) void {
        std.debug.print("Routing with grid {}x{}, start at {}, going {}\n", .{
            self.grid.rows(),
            self.grid.cols(),
            self.start,
            self.dir,
        });
        for (0..self.grid.rows()) |y| {
            for (0..self.grid.cols()) |x| {
                std.debug.print("{c}", .{self.grid.get(x, y)});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn findLetters(self: *Routing) ![]const u8 {
        try self.walk();
        return self.buf[0..self.len];
    }

    pub fn countSteps(self: *Routing) !usize {
        try self.walk();
        return self.count;
    }

    fn walk(self: *Routing) !void {
        var pos = self.start;
        var dir = self.dir;
        while (true) {
            const c = self.grid.get(pos.v[0], pos.v[1]);
            if (c == EMPTY) {
                break;
            }
            if (std.ascii.isAlphanumeric(c)) {
                self.buf[self.len] = c;
                self.len += 1;
            }

            self.count += 1;
            if (c == JUNCTURE) {
                for (Deltas) |d| {
                    if (d.valid(dir) and self.valid(pos, d.dx, d.dy)) {
                        dir = d.dir;
                        break;
                    }
                }
            }
            dir.move(&pos);
        }
    }

    fn valid(self: Routing, pos: Pos, dx: isize, dy: isize) bool {
        var x: isize = @intCast(pos.v[0]);
        x += dx;
        if (x < 0 or x >= self.grid.cols()) return false;

        var y: isize = @intCast(pos.v[1]);
        y += dy;
        if (y < 0 or y >= self.grid.rows()) return false;

        const ux: usize = @intCast(x);
        const uy: usize = @intCast(y);
        const c = self.grid.get(ux, uy);
        return c != EMPTY;
    }
};

test "sample part 1" {
    const data =
        \\     |          
        \\     |  +--+    
        \\     A  |  C    
        \\ F---|----E|--+ 
        \\     |  |  |  D 
        \\     +B-+  +--+
    ;

    var routing = Routing.init(std.testing.allocator);
    defer routing.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try routing.addLine(line);
    }
    // routing.show();

    const text = try routing.findLetters();
    const expected = "ABCDEF";
    try testing.expectEqualSlices(u8, expected, text);
}

test "sample part 2" {
    const data =
        \\     |          
        \\     |  +--+    
        \\     A  |  C    
        \\ F---|----E|--+ 
        \\     |  |  |  D 
        \\     +B-+  +--+
    ;

    var routing = Routing.init(std.testing.allocator);
    defer routing.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try routing.addLine(line);
    }
    // routing.show();

    const steps = try routing.countSteps();
    const expected = @as(usize, 38);
    try testing.expectEqual(expected, steps);
}
