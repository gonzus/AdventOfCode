const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const Burrow = struct {
    const Node = struct {
        code: u128,
        cost: usize,

        pub fn init(code: u128, cost: usize) Node {
            var self = Node{ .code = code, .cost = cost };
            return self;
        }

        fn lessThan(l: Node, r: Node) std.math.Order {
            return std.math.order(l.cost, r.cost);
        }
    };

    const State = struct {
        const HALLWAY_SIZE = 11;
        const HOME_SIZE = 4;
        const MAX_HOME_ROWS = 4;

        hallway: [HALLWAY_SIZE]u8,
        home: [MAX_HOME_ROWS][HOME_SIZE]u8,
        rows: u4,
        code: u128,

        pub fn init() State {
            var self = State{
                .hallway = undefined,
                .home = undefined,
                .code = 0,
                .rows = 0,
            };
            return self;
        }

        fn encode_pod(pod: u8) u3 {
            return switch (pod) {
                'A' => 0b100,
                'B' => 0b101,
                'C' => 0b110,
                'D' => 0b111,
                else => 0b000,
            };
        }

        fn decode_pod(pod: u3) u8 {
            return switch (pod) {
                0b100 => 'A',
                0b101 => 'B',
                0b110 => 'C',
                0b111 => 'D',
                else => '.',
            };
        }

        fn door_pos_for_home(home: u8) u5 {
            return @intCast(u5, (home - 'A' + 1) * 2);
        }

        fn home_for_pos(pos: u5) u8 {
            return switch (pos) {
                2 => 'A',
                4 => 'B',
                6 => 'C',
                8 => 'D',
                else => '.',
            };
        }

        fn unit_cost_for_pod(pod: u8) usize {
            return switch (pod) {
                'A' => 1,
                'B' => 10,
                'C' => 100,
                'D' => 1000,
                else => 0,
            };
        }

        fn is_valid_home_line(line: []const u8) bool {
            return (line[3] != '#' and line[5] != '#' and line[7] != '#' and line[9] != '#');
        }

        pub fn encode(self: *State) u128 {
            if (self.code == 0) {
                var w: usize = 0;
                while (w < HALLWAY_SIZE) : (w += 1) {
                    self.code <<= 3;
                    self.code |= encode_pod(self.hallway[w]);
                }

                var h: u8 = 'A';
                while (h <= 'D') : (h += 1) {
                    var p: usize = 0;
                    while (p < self.rows) : (p += 1) {
                        self.code <<= 3;
                        self.code |= encode_pod(self.get_home(h, p));
                    }
                }
                self.code <<= 4;
                self.code |= @intCast(u4, self.rows);
            }

            return self.code;
        }

        pub fn decode(code: u128) State {
            var c = code;
            var s = State.init();

            s.rows = @intCast(u4, c & 0b1111);
            c >>= 4;

            var h: u8 = 'D';
            while (h >= 'A') : (h -= 1) {
                var p: usize = 0;
                while (p < s.rows) : (p += 1) {
                    var x = @intCast(u3, c & 0b111);
                    c >>= 3;
                    s.set_home(h, s.rows - 1 - p, decode_pod(x));
                }
            }

            var w: usize = 0;
            while (w < HALLWAY_SIZE) : (w += 1) {
                var x = @intCast(u3, c & 0b111);
                c >>= 3;
                s.set_hallway(HALLWAY_SIZE - 1 - w, decode_pod(x));
            }

            s.code = code;
            return s;
        }

        fn parse_home_line(self: *State, line: []const u8, row: usize) void {
            var p: usize = 3;
            while (p <= 9) : (p += 2) {
                var h = @intCast(u8, (p - 3) / 2) + 'A';
                self.set_home(h, row, line[p]);
            }
        }

        pub fn parse_data(self: *State, data: []const u8) void {
            var y: usize = 0;
            var it = std.mem.split(u8, data, "\n");
            while (it.next()) |line| : (y += 1) {
                if (line.len == 0) continue;
                if (y == 0) continue;
                if (y == 1) {
                    for (line) |c, x| {
                        if (c == '#') continue;
                        self.hallway[x - 1] = c;
                    }
                    continue;
                }
                if (is_valid_home_line(line)) {
                    self.parse_home_line(line, self.rows);
                    self.rows += 1;
                }
            }
            self.code = 0;
        }

        pub fn parse_extra(self: *State, data: []const u8) void {
            var it = std.mem.split(u8, data, "\n");
            while (it.next()) |line| {
                if (line.len == 0) continue;
                if (is_valid_home_line(line)) {
                    var h: u8 = 'A';
                    while (h <= 'D') : (h += 1) {
                        self.set_home(h, self.rows, self.get_home(h, self.rows - 1));
                    }
                    self.parse_home_line(line, self.rows - 1);
                    self.rows += 1;
                }
            }
            self.code = 0;
        }

        pub fn build_target(self: *State) State {
            var s = self.*;
            var r: usize = 0;
            while (r < self.rows) : (r += 1) {
                var h: u8 = 'A';
                while (h <= 'D') : (h += 1) {
                    s.set_home(h, r, h);
                }
            }
            s.code = 0;
            return s;
        }

        pub fn show(self: State) void {
            std.debug.warn("#############\n", .{});

            std.debug.warn("#", .{});
            var w: usize = 0;
            while (w < HALLWAY_SIZE) : (w += 1) {
                std.debug.warn("{c}", .{self.hallway[w]});
            }
            std.debug.warn("#\n", .{});

            var p: usize = 0;
            while (p < self.rows) : (p += 1) {
                const f: u8 = if (p == 0) '#' else ' ';
                std.debug.warn("{c}{c}", .{ f, f });
                var h: u8 = 'A';
                while (h <= 'D') : (h += 1) {
                    std.debug.warn("#{c}", .{self.get_home(h, p)});
                }
                std.debug.warn("#{c}{c}\n", .{ f, f });
            }

            std.debug.warn("  #########  \n", .{});
        }

        pub fn get_hallway(self: State, pos: usize) u8 {
            return self.hallway[pos];
        }

        pub fn set_hallway(self: *State, pos: usize, val: u8) void {
            self.hallway[pos] = val;
            self.code = 0;
        }

        pub fn get_home(self: State, home: u8, pos: usize) u8 {
            return self.home[home - 'A'][pos];
        }

        pub fn set_home(self: *State, home: u8, pos: usize, val: u8) void {
            self.home[home - 'A'][pos] = val;
            self.code = 0;
        }

        pub fn pos_in_home_that_should_go_to_another_home(self: *State, home: u8) usize {
            var h: usize = 0;
            while (h < self.rows) : (h += 1) {
                if (self.get_home(home, h) != '.') break;
            }
            if (h >= self.rows) return 9;
            if (self.get_home(home, h) == home) return 9;

            return h;
        }

        pub fn pos_in_home_that_should_go_to_hallway(self: *State, home: u8) usize {
            var h: usize = 0;
            while (h < self.rows) : (h += 1) {
                if (self.get_home(home, h) != '.') break;
            }
            if (h >= self.rows) return 9;

            var l: usize = h;
            while (l < self.rows) : (l += 1) {
                if (self.get_home(home, l) != home) break;
            }
            if (l >= self.rows) return 9;
            return h;
        }

        pub fn pos_in_home_where_entering_pod_should_be_placed(self: *State, home: u8) usize {
            var h: usize = 0;
            while (h < self.rows) : (h += 1) {
                if (self.get_home(home, h) != '.') break;
            }
            if (h >= self.rows) return self.rows - 1;

            var l: usize = h;
            while (l < self.rows) : (l += 1) {
                if (self.get_home(home, l) != home) break;
            }
            if (l >= self.rows) return h - 1;
            return 9;
        }
    };

    const Scores = std.AutoHashMap(u128, usize);
    const Pending = std.PriorityQueue(Node, Node.lessThan);
    const Path = std.AutoHashMap(u128, Node);

    ini: State,
    end: State,
    min_score: usize,
    scores: Scores, // score for a given state; default is infinite
    pending: Pending, // a priority queue with the pending nodes to be analyzed
    path: Path, // the path to reach a given node

    pub fn init() Burrow {
        var self = Burrow{
            .ini = State.init(),
            .end = State.init(),
            .min_score = std.math.maxInt(usize),
            .scores = Scores.init(allocator),
            .pending = Pending.init(allocator),
            .path = Path.init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Burrow) void {
        self.path.deinit();
        self.pending.deinit();
        self.scores.deinit();
    }

    pub fn parse_data(self: *Burrow, data: []const u8) void {
        self.ini.parse_data(data);
        self.end = self.ini.build_target();
    }

    pub fn parse_extra(self: *Burrow, data: []const u8) void {
        self.ini.parse_extra(data);
        self.end = self.ini.build_target();
    }

    pub fn find_cheapest_solution(self: *Burrow) !usize {
        self.pending.shrinkAndFree(0);
        self.scores.clearRetainingCapacity();
        self.path.clearRetainingCapacity();

        try self.walk_dijkstra();

        var moves: usize = 0;
        var cost: usize = 0;
        var current = self.end.encode();
        while (true) {
            if (self.path.getEntry(current)) |e| {
                const node = e.value_ptr.*;
                moves += 1;
                cost += node.cost;
                // const parent = State.decode(node.code);
                // std.debug.warn("COST: {}\n\n", .{node.cost});
                // parent.show();
                current = node.code;
            } else {
                break;
            }
        }
        // std.debug.warn("Found solution with {} moves, total cost is {}\n", .{ moves, cost });
        return cost;
    }

    fn update_neighbor(self: *Burrow, piece: u8, length: usize, u: *State, v: *State, su: usize) !void {
        const cost = length * State.unit_cost_for_pod(piece);
        const tentative = su + cost;

        var sv: usize = std.math.maxInt(usize);
        if (self.scores.getEntry(v.encode())) |e| {
            sv = e.value_ptr.*;
        }
        if (tentative >= sv) return;

        try self.pending.add(Node.init(v.encode(), tentative));
        try self.scores.put(v.encode(), tentative);
        try self.path.put(v.encode(), Node.init(u.encode(), cost));
    }

    fn walk_dijkstra(self: *Burrow) !void {
        // we begin the route at the start node, which has a score of 0
        try self.pending.add(Node.init(self.ini.encode(), 0));
        while (self.pending.count() != 0) {
            const min_node = self.pending.remove();
            const uc = min_node.code;
            if (uc == self.end.encode()) {
                // found target -- yay!
                break;
            }

            const smin = min_node.cost;
            const su = smin;
            var u = State.decode(uc);

            // *** try to move from wrong home to right home ***
            {
                var source: u8 = 'D';
                while (source >= 'A') : (source -= 1) {
                    const p0 = u.pos_in_home_that_should_go_to_another_home(source);
                    if (p0 == 9) continue;

                    const target = u.get_home(source, p0);
                    if (target == '.') continue;

                    const p1 = u.pos_in_home_where_entering_pod_should_be_placed(target);
                    if (p1 == 9) continue;

                    var h0 = State.door_pos_for_home(source);
                    var h1 = State.door_pos_for_home(target);
                    if (h0 > h1) {
                        var t = h0;
                        h0 = h1;
                        h1 = t;
                    }
                    var blocked = false;
                    var h = h0;
                    while (h <= h1) : (h += 1) {
                        if (u.hallway[h] != '.') {
                            blocked = true;
                            break;
                        }
                    }
                    if (blocked) continue;

                    var v = u;
                    v.set_home(source, p0, '.');
                    v.set_home(target, p1, target);
                    // std.debug.warn("NEIGHBOR HOME-TO-HOME\n", .{});
                    // v.show();
                    const length = p0 + (h1 - h0 + 1) + p1 + 1;

                    try self.update_neighbor(target, length, &u, &v, su);
                }
            }

            // *** try to move from hallway to right home ***
            {
                var w: u5 = 0;
                while (w < State.HALLWAY_SIZE) : (w += 1) {
                    const target = u.get_hallway(w);
                    if (target == '.') continue;

                    const p1 = u.pos_in_home_where_entering_pod_should_be_placed(target);
                    if (p1 == 9) continue;

                    var h0 = w;
                    var h1 = State.door_pos_for_home(target);
                    if (h0 < h1) {
                        h0 += 1;
                    } else {
                        var t = h0;
                        h0 = h1;
                        h1 = t;
                        h1 -= 1;
                    }
                    var blocked = false;
                    var h = h0;
                    while (h <= h1) : (h += 1) {
                        if (u.hallway[h] != '.') {
                            blocked = true;
                            break;
                        }
                    }
                    if (blocked) continue;

                    var v = u;
                    v.set_hallway(w, '.');
                    v.set_home(target, p1, target);
                    // std.debug.warn("NEIGHBOR HALLWAY-TO-HOME\n", .{});
                    // v.show();
                    const length = (h1 - h0 + 1) + p1 + 1;
                    try self.update_neighbor(target, length, &u, &v, su);
                }
            }

            // *** try to move from wrong home to hallway ***
            {
                var source: u8 = 'A';
                while (source <= 'D') : (source += 1) {
                    const p0 = u.pos_in_home_that_should_go_to_hallway(source);
                    if (p0 == 9) continue;

                    const target = u.get_home(source, p0);
                    if (target == '.') continue;

                    const door = State.door_pos_for_home(source);

                    // to the left
                    var w: u5 = 0;
                    while (w < door) : (w += 1) {
                        var p: u5 = door - 1 - w;
                        if (u.get_hallway(p) != '.') break;
                        if (State.home_for_pos(p) != '.') continue;

                        var v = u;
                        v.set_hallway(p, target);
                        v.set_home(source, p0, '.');
                        // std.debug.warn("NEIGHBOR HOME-TO-HALLWAY (left {c} => {})\n", .{ target, p });
                        // v.show();
                        const length = p0 + (door - p + 1);
                        try self.update_neighbor(target, length, &u, &v, su);
                    }

                    // to the right
                    var p: u5 = door + 1;
                    while (p < State.HALLWAY_SIZE) : (p += 1) {
                        if (u.get_hallway(p) != '.') break;
                        if (State.home_for_pos(p) != '.') continue;

                        var v = u;
                        v.set_hallway(p, target);
                        v.set_home(source, p0, '.');
                        // std.debug.warn("NEIGHBOR HOME-TO-HALLWAY (right {c} => {})\n", .{ target, p });
                        // v.show();
                        const length = p0 + (p - door + 1);
                        try self.update_neighbor(target, length, &u, &v, su);
                    }
                }
            }
        }
    }
};

test "sample part a" {
    const data: []const u8 =
        \\#############
        \\#...........#
        \\###B#C#B#D###
        \\  #A#D#C#A#
        \\  #########
    ;

    var burrow = Burrow.init();
    defer burrow.deinit();

    burrow.parse_data(data);
    const cost = try burrow.find_cheapest_solution();
    try testing.expect(cost == 12521);
}

test "sample part b" {
    const data: []const u8 =
        \\#############
        \\#...........#
        \\###B#C#B#D###
        \\  #A#D#C#A#
        \\  #########
    ;

    const extra: []const u8 =
        \\  #D#C#B#A#
        \\  #D#B#A#C#
    ;

    var burrow = Burrow.init();
    defer burrow.deinit();

    burrow.parse_data(data);
    burrow.parse_extra(extra);

    const cost = try burrow.find_cheapest_solution();
    try testing.expect(cost == 44169);
}
