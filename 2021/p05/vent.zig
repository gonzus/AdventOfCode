const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const Vent = struct {
    pub const Mode = enum {
        HorVer,
        HorVerDiag,
    };

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            var self = Pos{
                .x = x,
                .y = y,
            };
            return self;
        }

        pub fn equal(self: Pos, other: Pos) bool {
            return self.x == other.x and self.y == other.y;
        }
    };

    const Line = struct {
        p1: Pos,
        p2: Pos,

        pub fn init(p1: Pos, p2: Pos) Line {
            var self = Line{
                .p1 = p1,
                .p2 = p2,
            };
            return self;
        }

        pub fn get_delta(self: Line) Pos {
            const sx1 = @intCast(isize, self.p1.x);
            const sx2 = @intCast(isize, self.p2.x);
            const sy1 = @intCast(isize, self.p1.y);
            const sy2 = @intCast(isize, self.p2.y);

            const dx = @intCast(usize, std.math.absInt(sx1 - sx2) catch unreachable);
            const dy = @intCast(usize, std.math.absInt(sy1 - sy2) catch unreachable);
            return Pos.init(dx, dy);
        }
    };

    mode: Mode,
    data: std.AutoHashMap(Pos, usize),

    pub fn init(mode: Mode) Vent {
        var self = Vent{
            .mode = mode,
            .data = std.AutoHashMap(Pos, usize).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Vent) void {
        self.data.deinit();
    }

    pub fn process_line(self: *Vent, data: []const u8) void {
        var l: Line = undefined;
        var ends: [2]Pos = undefined;
        var lpos: usize = 0;
        var itl = std.mem.tokenize(u8, data, " -> ");
        while (itl.next()) |point| : (lpos += 1) {
            var coords: [2]usize = undefined;
            var ppos: usize = 0;
            var itp = std.mem.tokenize(u8, point, ",");
            while (itp.next()) |num| : (ppos += 1) {
                const n = std.fmt.parseInt(usize, num, 10) catch unreachable;
                coords[ppos] = n;
                if (ppos >= 1) {
                    ends[lpos] = Pos.init(coords[0], coords[1]);
                    break;
                }
            }
            if (lpos >= 1) {
                l = Line.init(ends[0], ends[1]);
                break;
            }
        }
        // std.debug.warn("Line {}\n", .{l});

        const delta = l.get_delta();
        const dx: isize = if (l.p1.x < l.p2.x) 1 else -1;
        const dy: isize = if (l.p1.y < l.p2.y) 1 else -1;

        if (delta.y == 0) {
            // horizontal
            self.iterate_line(l, dx, 0);
        }

        if (delta.x == 0) {
            // vertical
            self.iterate_line(l, 0, dy);
        }

        if (self.mode == Mode.HorVer) return;

        if (delta.x == delta.y) {
            // diagonal at 45 degrees
            self.iterate_line(l, dx, dy);
        }
    }

    pub fn count_points_with_n_vents(self: Vent, n: usize) usize {
        var count: usize = 0;
        var it = self.data.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.* < n) continue;
            count += 1;
        }
        return count;
    }

    fn iterate_line(self: *Vent, l: Line, dx: isize, dy: isize) void {
        var x = @intCast(isize, l.p1.x);
        var y = @intCast(isize, l.p1.y);
        while (true) {
            const p = Pos.init(@intCast(usize, x), @intCast(usize, y));
            if (self.data.contains(p)) {
                var entry = self.data.getEntry(p).?;
                entry.value_ptr.* += 1;
            } else {
                self.data.put(p, 1) catch unreachable;
            }

            if (Pos.equal(p, l.p2)) break;
            x += dx;
            y += dy;
        }
    }
};

test "sample part a" {
    const data: []const u8 =
        \\0,9 -> 5,9
        \\8,0 -> 0,8
        \\9,4 -> 3,4
        \\2,2 -> 2,1
        \\7,0 -> 7,4
        \\6,4 -> 2,0
        \\0,9 -> 2,9
        \\3,4 -> 1,4
        \\0,0 -> 8,8
        \\5,5 -> 8,2
    ;

    var vent = Vent.init(Vent.Mode.HorVer);
    defer vent.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        vent.process_line(line);
    }

    const points = vent.count_points_with_n_vents(2);
    try testing.expect(points == 5);
}

test "sample part b" {
    const data: []const u8 =
        \\0,9 -> 5,9
        \\8,0 -> 0,8
        \\9,4 -> 3,4
        \\2,2 -> 2,1
        \\7,0 -> 7,4
        \\6,4 -> 2,0
        \\0,9 -> 2,9
        \\3,4 -> 1,4
        \\0,0 -> 8,8
        \\5,5 -> 8,2
    ;

    var vent = Vent.init(Vent.Mode.HorVerDiag);
    defer vent.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        vent.process_line(line);
    }

    const points = vent.count_points_with_n_vents(2);
    try testing.expect(points == 12);
}
