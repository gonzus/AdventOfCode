const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Network = struct {
    const BASE = ('9' - '0' + 1) + ('Z' - 'A' + 1);
    const SIZE = BASE * BASE * BASE; // 46_656, less than 50K

    const Pos = struct {
        text: [3]u8,
        value: usize,

        pub fn init() Pos {
            var self = Pos{
                .text = undefined,
                .value = 0,
            };
            return self;
        }

        pub fn setFromStr(self: *Pos, str: []const u8) void {
            for (str, 0..) |c, p| {
                self.text[p] = c;
                const n = switch (c) {
                    '0'...'9' => c - '0',
                    'a'...'z' => c - 'a' + 10,
                    'A'...'Z' => c - 'A' + 10,
                    else => unreachable,
                };
                self.value *= BASE;
                self.value += n;
            }
        }

        pub fn isSource(self: Pos, parallel: bool) bool {
            return self.isString(parallel, "AAA");
        }

        pub fn isTarget(self: Pos, parallel: bool) bool {
            return self.isString(parallel, "ZZZ");
        }

        fn isString(self: Pos, parallel: bool, str: []const u8) bool {
            if (parallel) {
                return self.text[2] == str[2];
            } else {
                return std.mem.eql(u8, &self.text, str);
            }
        }
    };

    const Dir = struct {
        L: Pos,
        R: Pos,

        pub fn init() Dir {
            var self = Dir{
                .L = Pos.init(),
                .R = Pos.init(),
            };
            return self;
        }
    };

    const Cycle = struct {
        length: usize,
        first: usize,

        pub fn init() Cycle {
            var self = Cycle{
                .length = 0,
                .first = 0,
            };
            return self;
        }

        pub fn rememberFirst(self: *Cycle) void {
            if (self.first > 0) return;
            self.first = self.length;
        }
    };

    allocator: Allocator,
    parallel: bool,
    line_num: usize,
    instructions: std.ArrayList(u8),
    srcs: std.ArrayList(Pos),
    directions: [SIZE]Dir,

    pub fn init(allocator: Allocator, parallel: bool) Network {
        var self = Network{
            .allocator = allocator,
            .parallel = parallel,
            .line_num = 0,
            .instructions = std.ArrayList(u8).init(allocator),
            .srcs = std.ArrayList(Pos).init(allocator),
            .directions = undefined,
        };
        return self;
    }

    pub fn deinit(self: *Network) void {
        self.srcs.deinit();
        self.instructions.deinit();
    }

    pub fn addLine(self: *Network, line: []const u8) !void {
        self.line_num += 1;

        if (line.len == 0) return;

        if (self.line_num == 1) {
            for (line) |c| {
                try self.instructions.append(c);
            }
            return;
        }

        var pos: usize = 0;
        var it = std.mem.tokenizeAny(u8, line, " =(,)");
        var src = Pos.init();
        var tgt = Dir.init();
        while (it.next()) |chunk| : (pos += 1) {
            switch (pos) {
                0 => src.setFromStr(chunk),
                1 => tgt.L.setFromStr(chunk),
                2 => tgt.R.setFromStr(chunk),
                else => unreachable,
            }
        }
        self.directions[src.value] = tgt;

        if (src.isSource(self.parallel)) {
            try self.srcs.append(src);
        }
    }

    pub fn getStepsToTraverse(self: *Network) !usize {
        var steps: usize = 1;
        for (self.srcs.items) |s| {
            // Although we do get the full cycle length here, there might be
            // more than one sub-cycle ending in Z. For example, the whole
            // cycle could take 100 steps, and there could be an ending Z at
            // steps 10, 27 and 50.
            //
            // I am not sure what the correct procedure would be in that case;
            // fortunately, for my data, each of the full cycles contains a
            // single step ending in Z :-)
            const cycle = try self.findCycle(s);
            steps = lcm(steps, cycle.first);
        }
        return steps;
    }

    fn findCycle(self: Network, pos: Pos) !Cycle {
        var seen = std.AutoHashMap(usize, void).init(self.allocator);
        defer seen.deinit();

        var cycle = Cycle.init();
        var instr_pos: usize = 0;
        var src = pos;
        while (true) {
            const key = src.value * 1000 + instr_pos;
            const entry = try seen.getOrPut(key);
            if (entry.found_existing) break;

            if (src.isTarget(self.parallel)) {
                cycle.rememberFirst();
            }
            cycle.length += 1;

            const dir = self.instructions.items[instr_pos];
            const tgt = switch (dir) {
                'L' => self.directions[src.value].L,
                'R' => self.directions[src.value].R,
                else => unreachable,
            };
            src = tgt;

            instr_pos += 1;
            if (instr_pos >= self.instructions.items.len) instr_pos = 0;
        }
        return cycle;
    }

    fn gcd(ca: usize, cb: usize) usize {
        var a = ca;
        var b = cb;
        while (b != 0) {
            const t = b;
            b = a % b;
            a = t;
        }
        return a;
    }

    fn lcm(a: usize, b: usize) usize {
        return (a * b) / gcd(a, b);
    }
};

test "sample small part 1" {
    const data =
        \\LLR
        \\
        \\AAA = (BBB, BBB)
        \\BBB = (AAA, ZZZ)
        \\ZZZ = (ZZZ, ZZZ)
    ;

    var network = Network.init(std.testing.allocator, false);
    defer network.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try network.addLine(line);
    }

    const steps = try network.getStepsToTraverse();
    const expected = @as(usize, 6);
    try testing.expectEqual(expected, steps);
}

test "sample medium part 1" {
    const data =
        \\RL
        \\
        \\AAA = (BBB, CCC)
        \\BBB = (DDD, EEE)
        \\CCC = (ZZZ, GGG)
        \\DDD = (DDD, DDD)
        \\EEE = (EEE, EEE)
        \\GGG = (GGG, GGG)
        \\ZZZ = (ZZZ, ZZZ)
    ;

    var network = Network.init(std.testing.allocator, false);
    defer network.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try network.addLine(line);
    }

    const steps = try network.getStepsToTraverse();
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, steps);
}

test "sample part 2" {
    const data =
        \\LR
        \\
        \\11A = (11B, XXX)
        \\11B = (XXX, 11Z)
        \\11Z = (11B, XXX)
        \\22A = (22B, XXX)
        \\22B = (22C, 22C)
        \\22C = (22Z, 22Z)
        \\22Z = (22B, 22B)
        \\XXX = (XXX, XXX)
    ;

    var network = Network.init(std.testing.allocator, true);
    defer network.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try network.addLine(line);
    }

    const steps = try network.getStepsToTraverse();
    const expected = @as(usize, 6);
    try testing.expectEqual(expected, steps);
}
