const std = @import("std");
const assert = std.debug.assert;
const allocator = std.heap.page_allocator;
const Computer = @import("./computer.zig").Computer;

pub const Pos = struct {
    const OFFSET: usize = 10000;

    x: usize,
    y: usize,

    pub fn init(x: usize, y: usize) Pos {
        return Pos{
            .x = x,
            .y = y,
        };
    }

    pub fn equal(self: Pos, other: Pos) bool {
        return self.x == other.x and self.y == other.y;
    }
};

pub const Map = struct {
    cells: std.AutoHashMap(Pos, Tile),
    computer: Computer,
    robot_dir: Dir,
    robot_tumbling: bool,
    pcur: Pos,
    pmin: Pos,
    pmax: Pos,

    pub const Dir = enum(u8) {
        N = 1,
        S = 2,
        W = 3,
        E = 4,

        pub fn reverse(d: Dir) Dir {
            return switch (d) {
                Dir.N => Dir.S,
                Dir.S => Dir.N,
                Dir.W => Dir.E,
                Dir.E => Dir.W,
            };
        }

        pub fn move(p: Pos, d: Dir) Pos {
            var q = p;
            switch (d) {
                Dir.N => q.y -= 1,
                Dir.S => q.y += 1,
                Dir.W => q.x -= 1,
                Dir.E => q.x += 1,
            }
            return q;
        }

        pub fn turn(c: Dir, w: Dir) ?Turn {
            var t: ?Turn = null;
            switch (c) {
                Dir.N => {
                    switch (w) {
                        Dir.N => t = null,
                        Dir.S => t = null,
                        Dir.W => t = Turn.L,
                        Dir.E => t = Turn.R,
                    }
                },
                Dir.S => {
                    switch (w) {
                        Dir.N => t = null,
                        Dir.S => t = null,
                        Dir.W => t = Turn.R,
                        Dir.E => t = Turn.L,
                    }
                },
                Dir.W => {
                    switch (w) {
                        Dir.N => t = Turn.R,
                        Dir.S => t = Turn.L,
                        Dir.W => t = null,
                        Dir.E => t = null,
                    }
                },
                Dir.E => {
                    switch (w) {
                        Dir.N => t = Turn.L,
                        Dir.S => t = Turn.R,
                        Dir.W => t = null,
                        Dir.E => t = null,
                    }
                },
            }
            return t;
        }
    };

    pub const Turn = enum(u8) {
        L = 'L',
        R = 'R',
    };

    pub const Tile = enum(u8) {
        Empty = '.',
        Scaffold = '#',
        Robot = '*',
    };

    pub fn init() Map {
        var self = Map{
            .cells = std.AutoHashMap(Pos, Tile).init(allocator),
            .computer = Computer.init(true),
            .robot_dir = undefined,
            .robot_tumbling = false,
            .pcur = undefined,
            .pmin = Pos.init(std.math.maxInt(usize), std.math.maxInt(usize)),
            .pmax = Pos.init(0, 0),
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.computer.deinit();
        self.cells.deinit();
    }

    pub fn run_to_get_map(self: *Map) void {
        var y: usize = 0;
        var x: usize = 0;
        main: while (true) {
            self.computer.run();
            while (true) {
                const output = self.computer.getOutput();
                // std.debug.warn("COMPUTER output {}\n",.{ output});
                if (output == null) break;
                var c = @intCast(u8, output.?);
                if (c == '\n') {
                    if (x == 0) break :main;
                    y += 1;
                    x = 0;
                    continue;
                }
                if (c == '^') {
                    self.robot_dir = Dir.N;
                    c = '*';
                }
                if (c == 'v') {
                    self.robot_dir = Dir.S;
                    c = '*';
                }
                if (c == '<') {
                    self.robot_dir = Dir.W;
                    c = '*';
                }
                if (c == '>') {
                    self.robot_dir = Dir.E;
                    c = '*';
                }
                if (c == 'X') {
                    self.robot_tumbling = true;
                    c = '*';
                }
                const t = @intToEnum(Tile, c);
                const p = Pos.init(x + Pos.OFFSET / 2, y + Pos.OFFSET / 2);
                self.set_pos(p, t);
                x += 1;
            }
            if (self.computer.halted) break;
        }
    }

    pub fn walk(self: *Map, route: *std.ArrayList(u8)) usize {
        var sum: usize = 0;
        var seen = std.AutoHashMap(Pos, void).init(allocator);
        var p: Pos = self.pcur;
        var d: Dir = undefined;
        var r: ?Dir = null;
        while (true) {
            var found: bool = false;
            var j: u8 = 1;
            while (j <= 4) : (j += 1) {
                d = @intToEnum(Dir, j);
                if (r != null and d == r.?) continue;
                const n = Dir.move(p, d);
                if (self.get_pos(n) == Tile.Scaffold) {
                    found = true;
                    p = n;
                    r = Dir.reverse(d);
                    break;
                }
            }
            if (!found) break;
            const t = Dir.turn(self.robot_dir, d);
            if (t != null) {
                // std.debug.warn("TURN from {} to {} => {}\n",.{ self.robot_dir, d, t.?});
                const c = @enumToInt(t.?);
                route.append(c) catch unreachable;
                route.append(',') catch unreachable;
                self.robot_dir = d;
            }
            // std.debug.warn("WALK 1 {} {}\n",.{ p.x - Pos.OFFSET / 2, p.y - Pos.OFFSET / 2});
            if (seen.contains(p)) {
                // std.debug.warn("CROSSING {} {}\n",.{ p.x, p.y});
                const alignment = (p.x - Pos.OFFSET / 2) * (p.y - Pos.OFFSET / 2);
                sum += alignment;
            } else {
                _ = seen.put(p, {}) catch unreachable;
            }
            var steps: usize = 1;
            while (true) {
                const n = Dir.move(p, d);
                if (self.get_pos(n) != Tile.Scaffold) {
                    break;
                }
                p = n;
                steps += 1;
                // std.debug.warn("WALK 2 {} {}\n",.{ p.x - Pos.OFFSET / 2, p.y - Pos.OFFSET / 2});
                if (seen.contains(p)) {
                    // std.debug.warn("CROSSING {} {}\n",.{ p.x, p.y});
                    const alignment = (p.x - Pos.OFFSET / 2) * (p.y - Pos.OFFSET / 2);
                    sum += alignment;
                } else {
                    _ = seen.put(p, {}) catch unreachable;
                }
            }
            // std.debug.warn("MOVE {} steps\n",.{ steps});
            var str: [30]u8 = undefined;
            const len = usizeToStr(steps, str[0..]);
            var k: usize = len;
            while (true) {
                k -= 1;
                route.append(str[k]) catch unreachable;
                if (k == 0) break;
            }
            route.append(',') catch unreachable;
        }
        return sum;
    }

    pub fn program_and_run(self: *Map) i64 {
        // TODO: found these "by hand" -- shameful!
        const program =
            \\C,B,B,A,A,C,C,B,B,A
            \\R,12,R,4,L,6,L,8,L,8
            \\R,12,R,4,L,12
            \\L,12,R,4,R,4
            \\n
        ;
        var it = std.mem.split(u8, program, "\n");
        while (it.next()) |line| {
            var j: usize = 0;
            while (j < line.len) : (j += 1) {
                self.computer.enqueueInput(line[j]);
            }
            self.computer.enqueueInput('\n');
        }
        while (!self.computer.halted)
            self.computer.run();

        std.debug.warn("== PROGRAM OUTPUT ==\n", .{});
        var dust: i64 = 0;
        while (true) {
            const result = self.computer.getOutput();
            if (result == null) break;
            if (result.? >= 0 and result.? < 256) {
                const c = @intCast(u8, result.?);
                std.debug.warn("{c}", .{c});
            } else {
                dust = result.?;
            }
        }
        return dust;
    }

    pub fn split_route(self: *Map, route: []const u8) usize {
        _ = self;
        std.debug.warn("SPLIT {} bytes: [{}]\n", .{ route.len, route });
        // var seen = std.StringHashMap(usize).init(allocator);

        var j: usize = 0;
        while (j < route.len) {
            var commas: usize = 0;
            var k: usize = j + 1;
            while (k < route.len) : (k += 1) {
                if (route[k] == ',') commas += 1;
                if (commas >= 6) break;
            }
            const slice = route[j..k];
            const top = route.len - slice.len;
            var count: usize = 0;
            // std.debug.warn("SLICE [{}] with {} bytes, top byte {}\n",.{ slice, slice.len, top});
            k += 1;
            while (k < top) : (k += 1) {
                // std.debug.warn("CMP pos {}\n",.{ k});
                if (std.mem.eql(u8, slice, route[k .. k + slice.len])) {
                    count += 1;
                    if (count == 1) {
                        std.debug.warn("SLICE #0 {} bytes at {}-{}: [{}]\n", .{ slice.len, j, j + slice.len, slice });
                    }
                    std.debug.warn("MATCH #{} {} bytes at {}-{}: [{}]\n", .{ count, slice.len, k, k + slice.len, slice });
                }
            }
            commas = 0;
            while (j < route.len) : (j += 1) {
                if (route[j] == ',') commas += 1;
                if (commas >= 2) break;
            }
            j += 1;
        }
        return 0;
    }

    fn usizeToStr(n: usize, str: []u8) usize {
        var m: usize = n;
        var p: usize = 0;
        while (true) {
            const d = @intCast(u8, m % 10);
            m /= 10;
            str[p] = d + '0';
            p += 1;
            if (m == 0) break;
        }
        return p;
    }

    pub fn get_pos(self: *Map, pos: Pos) Tile {
        if (!self.cells.contains(pos)) {
            return Tile.Empty;
        }
        return self.cells.get(pos).?;
    }

    pub fn set_pos(self: *Map, pos: Pos, mark: Tile) void {
        _ = self.cells.put(pos, mark) catch unreachable;
        if (self.pmin.x > pos.x) self.pmin.x = pos.x;
        if (self.pmin.y > pos.y) self.pmin.y = pos.y;
        if (self.pmax.x < pos.x) self.pmax.x = pos.x;
        if (self.pmax.y < pos.y) self.pmax.y = pos.y;
        if (mark == Tile.Robot) {
            self.pcur = pos;
        }
    }

    pub fn show(self: Map) void {
        const sx = self.pmax.x - self.pmin.x + 1;
        const sy = self.pmax.y - self.pmin.y + 1;
        std.debug.warn("MAP: {} x {} - {} {} - {} {}\n", .{ sx, sy, self.pmin.x, self.pmin.y, self.pmax.x, self.pmax.y });
        std.debug.warn("ROBOT: {} {}\n", .{ self.pcur.x, self.pcur.y });
        var y: usize = self.pmin.y;
        while (y <= self.pmax.y) : (y += 1) {
            std.debug.warn("{:4} | ", .{y});
            var x: usize = self.pmin.x;
            while (x <= self.pmax.x) : (x += 1) {
                const p = Pos.init(x, y);
                const g = self.cells.get(p);
                var t: u8 = ' ';
                if (g != null) {
                    const c = g.?.value;
                    t = @enumToInt(c);
                }
                if (p.equal(self.pcur)) {
                    t = switch (self.robot_dir) {
                        Dir.N => '^',
                        Dir.S => 'v',
                        Dir.W => '<',
                        Dir.E => '>',
                    };
                    if (self.robot_tumbling) {
                        t = 'X';
                    }
                }

                std.debug.warn("{c}", .{t});
            }
            std.debug.warn("\n", .{});
        }
    }
};

test "find intersections and alignments" {
    const data =
        \\..#..........
        \\..#..........
        \\#######...###
        \\#.#...#...#.#
        \\#############
        \\..#...#...#..
        \\..#####...^..
    ;

    var map = Map.init();
    defer map.deinit();

    var y: usize = 0;
    var itl = std.mem.split(u8, data, "\n");
    while (itl.next()) |line| : (y += 1) {
        var x: usize = 0;
        while (x < line.len) : (x += 1) {
            const p = Pos.init(x + Pos.OFFSET / 2, y + Pos.OFFSET / 2);
            var t: Map.Tile = Map.Tile.Empty;
            if (line[x] == '#') t = Map.Tile.Scaffold;
            if (line[x] == '^') {
                t = Map.Tile.Robot;
                map.pcur = p;
                map.robot_dir = Map.Dir.N;
            }
            if (line[x] == 'v') {
                t = Map.Tile.Robot;
                map.pcur = p;
                map.robot_dir = Map.Dir.S;
            }
            if (line[x] == '<') {
                t = Map.Tile.Robot;
                map.pcur = p;
                map.robot_dir = Map.Dir.W;
            }
            if (line[x] == '>') {
                t = Map.Tile.Robot;
                map.pcur = p;
                map.robot_dir = Map.Dir.E;
            }
            if (line[x] == 'X') {
                t = Map.Tile.Robot;
                map.pcur = p;
                map.robot_tumbling = true;
            }
            map.set_pos(p, t);
        }
    }

    var route = std.ArrayList(u8).init(allocator);
    defer route.deinit();

    const result = map.walk(&route);
    assert(result == 76);
}

test "find correct route" {
    const data =
        \\#######...#####
        \\#.....#...#...#
        \\#.....#...#...#
        \\......#...#...#
        \\......#...###.#
        \\......#.....#.#
        \\^########...#.#
        \\......#.#...#.#
        \\......#########
        \\........#...#..
        \\....#########..
        \\....#...#......
        \\....#...#......
        \\....#...#......
        \\....#####......
    ;

    var map = Map.init();
    defer map.deinit();

    var y: usize = 0;
    var itl = std.mem.split(u8, data, "\n");
    while (itl.next()) |line| : (y += 1) {
        var x: usize = 0;
        while (x < line.len) : (x += 1) {
            const p = Pos.init(x + Pos.OFFSET / 2, y + Pos.OFFSET / 2);
            var t: Map.Tile = Map.Tile.Empty;
            if (line[x] == '#') t = Map.Tile.Scaffold;
            if (line[x] == '^') {
                t = Map.Tile.Robot;
                map.pcur = p;
                map.robot_dir = Map.Dir.N;
            }
            if (line[x] == 'v') {
                t = Map.Tile.Robot;
                map.pcur = p;
                map.robot_dir = Map.Dir.S;
            }
            if (line[x] == '<') {
                t = Map.Tile.Robot;
                map.pcur = p;
                map.robot_dir = Map.Dir.W;
            }
            if (line[x] == '>') {
                t = Map.Tile.Robot;
                map.pcur = p;
                map.robot_dir = Map.Dir.E;
            }
            if (line[x] == 'X') {
                t = Map.Tile.Robot;
                map.pcur = p;
                map.robot_tumbling = true;
            }
            map.set_pos(p, t);
        }
    }

    var route = std.ArrayList(u8).init(allocator);
    defer route.deinit();

    _ = map.walk(&route);
    const slice = route.toOwnedSlice();
    const wanted = "R,8,R,8,R,4,R,4,R,8,L,6,L,2,R,4,R,4,R,8,R,8,R,8,L,6,L,2";
    const wanted_comma = wanted ++ ",";

    assert(std.mem.eql(u8, slice, wanted) or std.mem.eql(u8, slice, wanted_comma));
}

test "split program matches" {
    const original = "L,12,R,4,R,4,R,12,R,4,L,12,R,12,R,4,L,12,R,12,R,4,L,6,L,8,L,8,R,12,R,4,L,6,L,8,L,8,L,12,R,4,R,4,L,12,R,4,R,4,R,12,R,4,L,12,R,12,R,4,L,12,R,12,R,4,L,6,L,8,L,8";
    const main = "C,B,B,A,A,C,C,B,B,A";
    const routines =
        \\R,12,R,4,L,6,L,8,L,8
        \\R,12,R,4,L,12
        \\L,12,R,4,R,4
    ;

    var j: usize = 0;
    var routine: [3][]const u8 = undefined;
    var itr = std.mem.split(u8, routines, "\n");
    while (itr.next()) |line| : (j += 1) {
        routine[j] = line;
    }

    var output: [original.len * 2]u8 = undefined;
    var pos: usize = 0;
    var itm = std.mem.split(u8, main, ",");
    while (itm.next()) |name| {
        const index = name[0] - 'A';
        std.mem.copy(u8, output[pos..], routine[index]);
        pos += routine[index].len;
        std.mem.copy(u8, output[pos..], ",");
        pos += 1;
    }
    assert(std.mem.eql(u8, original, output[0..original.len]));
}
