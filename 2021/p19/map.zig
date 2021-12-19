const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const Map = struct {
    const MATCHES_NEEDED = 12;

    pub const Rotations = [24][3][3]isize{
        [3][3]isize{
            [3]isize{ 1, 0, 0 },
            [3]isize{ 0, 1, 0 },
            [3]isize{ 0, 0, 1 },
        },
        [3][3]isize{
            [3]isize{ 1, 0, 0 },
            [3]isize{ 0, 0, -1 },
            [3]isize{ 0, 1, 0 },
        },
        [3][3]isize{
            [3]isize{ 1, 0, 0 },
            [3]isize{ 0, -1, 0 },
            [3]isize{ 0, 0, -1 },
        },
        [3][3]isize{
            [3]isize{ 1, 0, 0 },
            [3]isize{ 0, 0, 1 },
            [3]isize{ 0, -1, 0 },
        },
        [3][3]isize{
            [3]isize{ 0, -1, 0 },
            [3]isize{ 1, 0, 0 },
            [3]isize{ 0, 0, 1 },
        },
        [3][3]isize{
            [3]isize{ 0, 0, 1 },
            [3]isize{ 1, 0, 0 },
            [3]isize{ 0, 1, 0 },
        },
        [3][3]isize{
            [3]isize{ 0, 1, 0 },
            [3]isize{ 1, 0, 0 },
            [3]isize{ 0, 0, -1 },
        },
        [3][3]isize{
            [3]isize{ 0, 0, -1 },
            [3]isize{ 1, 0, 0 },
            [3]isize{ 0, -1, 0 },
        },
        [3][3]isize{
            [3]isize{ -1, 0, 0 },
            [3]isize{ 0, -1, 0 },
            [3]isize{ 0, 0, 1 },
        },
        [3][3]isize{
            [3]isize{ -1, 0, 0 },
            [3]isize{ 0, 0, -1 },
            [3]isize{ 0, -1, 0 },
        },
        [3][3]isize{
            [3]isize{ -1, 0, 0 },
            [3]isize{ 0, 1, 0 },
            [3]isize{ 0, 0, -1 },
        },
        [3][3]isize{
            [3]isize{ -1, 0, 0 },
            [3]isize{ 0, 0, 1 },
            [3]isize{ 0, 1, 0 },
        },
        [3][3]isize{
            [3]isize{ 0, 1, 0 },
            [3]isize{ -1, 0, 0 },
            [3]isize{ 0, 0, 1 },
        },
        [3][3]isize{
            [3]isize{ 0, 0, 1 },
            [3]isize{ -1, 0, 0 },
            [3]isize{ 0, -1, 0 },
        },
        [3][3]isize{
            [3]isize{ 0, -1, 0 },
            [3]isize{ -1, 0, 0 },
            [3]isize{ 0, 0, -1 },
        },
        [3][3]isize{
            [3]isize{ 0, 0, -1 },
            [3]isize{ -1, 0, 0 },
            [3]isize{ 0, 1, 0 },
        },
        [3][3]isize{
            [3]isize{ 0, 0, -1 },
            [3]isize{ 0, 1, 0 },
            [3]isize{ 1, 0, 0 },
        },
        [3][3]isize{
            [3]isize{ 0, 1, 0 },
            [3]isize{ 0, 0, 1 },
            [3]isize{ 1, 0, 0 },
        },
        [3][3]isize{
            [3]isize{ 0, 0, 1 },
            [3]isize{ 0, -1, 0 },
            [3]isize{ 1, 0, 0 },
        },
        [3][3]isize{
            [3]isize{ 0, -1, 0 },
            [3]isize{ 0, 0, -1 },
            [3]isize{ 1, 0, 0 },
        },
        [3][3]isize{
            [3]isize{ 0, 0, -1 },
            [3]isize{ 0, -1, 0 },
            [3]isize{ -1, 0, 0 },
        },
        [3][3]isize{
            [3]isize{ 0, -1, 0 },
            [3]isize{ 0, 0, 1 },
            [3]isize{ -1, 0, 0 },
        },
        [3][3]isize{
            [3]isize{ 0, 0, 1 },
            [3]isize{ 0, 1, 0 },
            [3]isize{ -1, 0, 0 },
        },
        [3][3]isize{
            [3]isize{ 0, 1, 0 },
            [3]isize{ 0, 0, -1 },
            [3]isize{ -1, 0, 0 },
        },
    };

    const State = enum { SCANNER, BUOY };

    const Pos = struct {
        x: isize,
        y: isize,
        z: isize,

        pub fn init(x: isize, y: isize, z: isize) Pos {
            var self = Pos{ .x = x, .y = y, .z = z };
            return self;
        }

        pub fn equal(self: Pos, other: Pos) bool {
            return self.x == other.x and self.y == other.y and self.z == other.z;
        }

        pub fn distance_squared(self: Pos, other: Pos) usize {
            const dx = self.x - other.x;
            const ux = @intCast(usize, dx * dx);
            const dy = self.y - other.y;
            const uy = @intCast(usize, dy * dy);
            const dz = self.z - other.z;
            const uz = @intCast(usize, dz * dz);
            return ux + uy + uz;
        }

        pub fn manhattan_distance(self: Pos, other: Pos) usize {
            const dx = @intCast(usize, std.math.absInt(self.x - other.x) catch unreachable);
            const dy = @intCast(usize, std.math.absInt(self.y - other.y) catch unreachable);
            const dz = @intCast(usize, std.math.absInt(self.z - other.z) catch unreachable);
            return dx + dy + dz;
        }

        fn rotate(self: Pos, rot: [3][3]isize) Pos {
            var p: Pos = Pos.init(
                self.x * rot[0][0] + self.y * rot[0][1] + self.z * rot[0][2],
                self.x * rot[1][0] + self.y * rot[1][1] + self.z * rot[1][2],
                self.x * rot[2][0] + self.y * rot[2][1] + self.z * rot[2][2],
            );
            return p;
        }

        pub fn rot_and_trans(self: Pos, rot: [3][3]isize, trans: Pos) Pos {
            var p = self.rotate(rot);
            p.x += trans.x;
            p.y += trans.y;
            p.z += trans.z;
            return p;
        }
    };

    const Beacon = struct {
        name: usize,
        pos: Pos,
        dists: std.AutoHashMap(usize, Pos),

        pub fn init(name: usize, pos: Pos) Beacon {
            var self = Beacon{
                .name = name,
                .pos = pos,
                .dists = std.AutoHashMap(usize, Pos).init(allocator),
            };
            return self;
        }

        pub fn deinit(self: *Beacon) void {
            self.dists.deinit();
        }
    };

    const Scanner = struct {
        name: usize,
        pos_for_scanners: std.ArrayList(Pos),
        beacons: std.ArrayList(Beacon),

        pub fn init(name: usize) Scanner {
            var self = Scanner{
                .name = name,
                .pos_for_scanners = std.ArrayList(Pos).init(allocator),
                .beacons = std.ArrayList(Beacon).init(allocator),
            };
            const own = Pos.init(0, 0, 0);
            self.pos_for_scanners.append(own) catch unreachable;
            return self;
        }

        pub fn deinit(self: *Scanner) void {
            for (self.beacons.items) |*b| {
                b.deinit();
            }
            self.beacons.deinit();
            self.pos_for_scanners.deinit();
        }

        fn compute_distances_between_beacons(self: *Scanner) !void {
            for (self.beacons.items) |*b0, j0| {
                for (self.beacons.items) |b1, j1| {
                    if (j0 == j1) continue;
                    const d = b0.pos.distance_squared(b1.pos);
                    try b0.*.dists.put(d, b1.pos);
                }
            }
        }

        pub fn match_scanners(self: *Scanner, other: *Scanner) !bool {
            var matches = std.AutoHashMap(Pos, Pos).init(allocator);
            defer matches.deinit();

            try self.compute_distances_between_beacons();
            try other.compute_distances_between_beacons();

            for (self.beacons.items) |b0| {
                for (other.beacons.items) |b1| {
                    var total: usize = 1;
                    var count: usize = 1;
                    var it = b1.dists.iterator();
                    while (it.next()) |e| {
                        total += 1;
                        const d = e.key_ptr.*;
                        if (!b0.dists.contains(d)) continue;
                        count += 1;
                    }
                    if (count < MATCHES_NEEDED) continue;
                    try matches.put(b0.pos, b1.pos);
                    // std.debug.warn("-- MATCH beacon {} {} with beacon {} {}: {} / {} matches\n", .{ b0.name, b0.pos, b1.name, b1.pos, count, total });
                }
            }

            const size = matches.count();
            if (size <= 0) {
                // std.debug.warn("*** NO MATCH BETWEEN scanner {} and {}\n", .{ self.name, other.name });
                return false;
            }

            // std.debug.warn("*** MATCHED scanner {} ({} beacons) and {} ({} beacons), {} beacons match\n", .{ self.name, self.beacons.items.len, other.name, other.beacons.items.len, size });
            for (Map.Rotations) |rot| {
                var delta = Pos.init(0, 0, 0);
                var first: bool = true;
                var candidate: bool = true;
                var it = matches.iterator();
                while (it.next()) |e| {
                    const p0 = e.key_ptr.*;
                    const p1 = e.value_ptr.*;
                    const rotated = p0.rotate(rot);
                    const new = Pos.init(p1.x - rotated.x, p1.y - rotated.y, p1.z - rotated.z);
                    if (first) {
                        first = false;
                        delta = new;
                        continue;
                    }
                    if (!Pos.equal(delta, new)) {
                        candidate = false;
                    }
                }
                if (candidate) {
                    // std.debug.warn("CORRECT ROT IS {d} => scanner {} is at {}\n", .{ rot, self.name, self.pos });

                    // now dump all rotated beacons from self into other, which were not matched
                    var dumps: usize = 0;
                    for (self.beacons.items) |*b| {
                        if (matches.contains(b.pos)) {
                            // std.debug.warn("SKIPPING MATCHED BEACON\n", .{});
                            b.deinit();
                            continue;
                        }
                        b.pos = b.pos.rot_and_trans(rot, delta);
                        try other.beacons.append(b.*);
                        dumps += 1;
                    }
                    for (self.pos_for_scanners.items) |p| {
                        const new = p.rot_and_trans(rot, delta);
                        try other.pos_for_scanners.append(new);
                    }
                    self.beacons.clearRetainingCapacity();
                    // std.debug.warn("TRANSFERRED {} UNMATCHED BEACONS => {} TOTAL\n", .{ dumps, other.beacons.items.len });
                }
            }
            return true;
        }

        pub fn show(self: Scanner) !void {
            std.debug.warn("SCANNER {}\n", .{self.name});
            for (self.beacons.items) |b, j| {
                std.debug.warn("BUOY {}:", .{j});
                var it = b.dists.iterator();
                while (it.next()) |e| {
                    std.debug.warn(" {}", .{e.key_ptr.*});
                }
                std.debug.warn("\n", .{});
            }
        }
    };

    state: State,
    current: usize,
    scanners: std.AutoHashMap(usize, *Scanner),
    matched: bool,

    pub fn init() Map {
        var self = Map{
            .state = State.SCANNER,
            .current = 0,
            .scanners = std.AutoHashMap(usize, *Scanner).init(allocator),
            .matched = false,
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        var it = self.scanners.iterator();
        while (it.next()) |e| {
            var s = e.value_ptr.*;
            s.deinit();
            allocator.destroy(s);
        }
        self.scanners.deinit();
    }

    pub fn process_line(self: *Map, data: []const u8) !void {
        switch (self.state) {
            State.SCANNER => {
                if (data[0] != '-') unreachable;
                var pos: usize = 0;
                var it = std.mem.tokenize(u8, data, " ");
                while (it.next()) |what| : (pos += 1) {
                    if (pos != 2) continue;
                    self.current = std.fmt.parseInt(usize, what, 10) catch unreachable;
                    var s = allocator.create(Scanner) catch unreachable;
                    s.* = Scanner.init(self.current);
                    try self.scanners.put(self.current, s);
                    break;
                }
                self.state = State.BUOY;
            },
            State.BUOY => {
                if (data.len == 0) {
                    self.state = State.SCANNER;
                    return;
                }
                var p: Pos = undefined;
                var pos: usize = 0;
                var it = std.mem.split(u8, data, ",");
                while (it.next()) |num| : (pos += 1) {
                    const n = std.fmt.parseInt(isize, num, 10) catch unreachable;
                    if (pos == 0) {
                        p.x = n;
                        continue;
                    }
                    if (pos == 1) {
                        p.y = n;
                        continue;
                    }
                    if (pos == 2) {
                        p.z = n;
                        var s = self.scanners.get(self.current).?;
                        var l = s.beacons.items.len;
                        var b = Beacon.init(l, p);
                        try s.*.beacons.append(b);
                        p = undefined;
                        continue;
                    }
                    unreachable;
                }
            },
        }
    }

    pub fn match_all_scanners(self: *Map) !usize {
        if (!self.matched) {
            self.matched = true;

            const n = self.scanners.count();
            var j0: usize = 0;
            while (j0 < n) : (j0 += 1) {
                var s0 = self.scanners.get(n - 1 - j0).?;
                var j1: usize = j0 + 1;
                while (j1 < n) : (j1 += 1) {
                    var s1 = self.scanners.get(n - 1 - j1).?;
                    if (try s0.match_scanners(s1)) break;
                }
            }
        }
        const beacons = self.scanners.get(0).?.beacons.items.len;
        // std.debug.warn("BEACONS {} \n", .{beacons});
        return beacons;
    }

    pub fn find_largest_manhattan(self: *Map) !usize {
        _ = try self.match_all_scanners();
        var largest: usize = 0;
        const s = self.scanners.get(0).?;
        for (s.pos_for_scanners.items) |p0, j| {
            for (s.pos_for_scanners.items[j + 1 ..]) |p1| {
                var m = p0.manhattan_distance(p1);
                if (largest < m) largest = m;
            }
        }
        // std.debug.warn("LARGEST {} \n", .{largest});
        return largest;
    }

    pub fn show(self: Map) !void {
        const n = self.scanners.count();
        std.debug.warn("MAP with {} scanners\n", .{n});
        var j: usize = 0;
        while (j < n) : (j += 1) {
            var s = self.scanners.get(j).?;
            // std.debug.warn("SCANNER {}:\n", .{e.key_ptr.*});
            try s.show();
        }
    }
};

test "sample part a" {
    const data: []const u8 =
        \\--- scanner 0 ---
        \\404,-588,-901
        \\528,-643,409
        \\-838,591,734
        \\390,-675,-793
        \\-537,-823,-458
        \\-485,-357,347
        \\-345,-311,381
        \\-661,-816,-575
        \\-876,649,763
        \\-618,-824,-621
        \\553,345,-567
        \\474,580,667
        \\-447,-329,318
        \\-584,868,-557
        \\544,-627,-890
        \\564,392,-477
        \\455,729,728
        \\-892,524,684
        \\-689,845,-530
        \\423,-701,434
        \\7,-33,-71
        \\630,319,-379
        \\443,580,662
        \\-789,900,-551
        \\459,-707,401
        \\
        \\--- scanner 1 ---
        \\686,422,578
        \\605,423,415
        \\515,917,-361
        \\-336,658,858
        \\95,138,22
        \\-476,619,847
        \\-340,-569,-846
        \\567,-361,727
        \\-460,603,-452
        \\669,-402,600
        \\729,430,532
        \\-500,-761,534
        \\-322,571,750
        \\-466,-666,-811
        \\-429,-592,574
        \\-355,545,-477
        \\703,-491,-529
        \\-328,-685,520
        \\413,935,-424
        \\-391,539,-444
        \\586,-435,557
        \\-364,-763,-893
        \\807,-499,-711
        \\755,-354,-619
        \\553,889,-390
        \\
        \\--- scanner 2 ---
        \\649,640,665
        \\682,-795,504
        \\-784,533,-524
        \\-644,584,-595
        \\-588,-843,648
        \\-30,6,44
        \\-674,560,763
        \\500,723,-460
        \\609,671,-379
        \\-555,-800,653
        \\-675,-892,-343
        \\697,-426,-610
        \\578,704,681
        \\493,664,-388
        \\-671,-858,530
        \\-667,343,800
        \\571,-461,-707
        \\-138,-166,112
        \\-889,563,-600
        \\646,-828,498
        \\640,759,510
        \\-630,509,768
        \\-681,-892,-333
        \\673,-379,-804
        \\-742,-814,-386
        \\577,-820,562
        \\
        \\--- scanner 3 ---
        \\-589,542,597
        \\605,-692,669
        \\-500,565,-823
        \\-660,373,557
        \\-458,-679,-417
        \\-488,449,543
        \\-626,468,-788
        \\338,-750,-386
        \\528,-832,-391
        \\562,-778,733
        \\-938,-730,414
        \\543,643,-506
        \\-524,371,-870
        \\407,773,750
        \\-104,29,83
        \\378,-903,-323
        \\-778,-728,485
        \\426,699,580
        \\-438,-605,-362
        \\-469,-447,-387
        \\509,732,623
        \\647,635,-688
        \\-868,-804,481
        \\614,-800,639
        \\595,780,-596
        \\
        \\--- scanner 4 ---
        \\727,592,562
        \\-293,-554,779
        \\441,611,-461
        \\-714,465,-776
        \\-743,427,-804
        \\-660,-479,-426
        \\832,-632,460
        \\927,-485,-438
        \\408,393,-506
        \\466,436,-512
        \\110,16,151
        \\-258,-428,682
        \\-393,719,612
        \\-211,-452,876
        \\808,-476,-593
        \\-575,615,604
        \\-485,667,467
        \\-680,325,-822
        \\-627,-443,-432
        \\872,-547,-609
        \\833,512,582
        \\807,604,487
        \\839,-516,451
        \\891,-625,532
        \\-652,-548,-490
        \\30,-46,-14
    ;

    var map = Map.init();
    defer map.deinit();
    // map.show();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    // try map.show();
    const unique = try map.match_all_scanners();
    try testing.expect(unique == 79);
}

test "sample part b" {
    const data: []const u8 =
        \\--- scanner 0 ---
        \\404,-588,-901
        \\528,-643,409
        \\-838,591,734
        \\390,-675,-793
        \\-537,-823,-458
        \\-485,-357,347
        \\-345,-311,381
        \\-661,-816,-575
        \\-876,649,763
        \\-618,-824,-621
        \\553,345,-567
        \\474,580,667
        \\-447,-329,318
        \\-584,868,-557
        \\544,-627,-890
        \\564,392,-477
        \\455,729,728
        \\-892,524,684
        \\-689,845,-530
        \\423,-701,434
        \\7,-33,-71
        \\630,319,-379
        \\443,580,662
        \\-789,900,-551
        \\459,-707,401
        \\
        \\--- scanner 1 ---
        \\686,422,578
        \\605,423,415
        \\515,917,-361
        \\-336,658,858
        \\95,138,22
        \\-476,619,847
        \\-340,-569,-846
        \\567,-361,727
        \\-460,603,-452
        \\669,-402,600
        \\729,430,532
        \\-500,-761,534
        \\-322,571,750
        \\-466,-666,-811
        \\-429,-592,574
        \\-355,545,-477
        \\703,-491,-529
        \\-328,-685,520
        \\413,935,-424
        \\-391,539,-444
        \\586,-435,557
        \\-364,-763,-893
        \\807,-499,-711
        \\755,-354,-619
        \\553,889,-390
        \\
        \\--- scanner 2 ---
        \\649,640,665
        \\682,-795,504
        \\-784,533,-524
        \\-644,584,-595
        \\-588,-843,648
        \\-30,6,44
        \\-674,560,763
        \\500,723,-460
        \\609,671,-379
        \\-555,-800,653
        \\-675,-892,-343
        \\697,-426,-610
        \\578,704,681
        \\493,664,-388
        \\-671,-858,530
        \\-667,343,800
        \\571,-461,-707
        \\-138,-166,112
        \\-889,563,-600
        \\646,-828,498
        \\640,759,510
        \\-630,509,768
        \\-681,-892,-333
        \\673,-379,-804
        \\-742,-814,-386
        \\577,-820,562
        \\
        \\--- scanner 3 ---
        \\-589,542,597
        \\605,-692,669
        \\-500,565,-823
        \\-660,373,557
        \\-458,-679,-417
        \\-488,449,543
        \\-626,468,-788
        \\338,-750,-386
        \\528,-832,-391
        \\562,-778,733
        \\-938,-730,414
        \\543,643,-506
        \\-524,371,-870
        \\407,773,750
        \\-104,29,83
        \\378,-903,-323
        \\-778,-728,485
        \\426,699,580
        \\-438,-605,-362
        \\-469,-447,-387
        \\509,732,623
        \\647,635,-688
        \\-868,-804,481
        \\614,-800,639
        \\595,780,-596
        \\
        \\--- scanner 4 ---
        \\727,592,562
        \\-293,-554,779
        \\441,611,-461
        \\-714,465,-776
        \\-743,427,-804
        \\-660,-479,-426
        \\832,-632,460
        \\927,-485,-438
        \\408,393,-506
        \\466,436,-512
        \\110,16,151
        \\-258,-428,682
        \\-393,719,612
        \\-211,-452,876
        \\808,-476,-593
        \\-575,615,604
        \\-485,667,467
        \\-680,325,-822
        \\-627,-443,-432
        \\872,-547,-609
        \\833,512,582
        \\807,604,487
        \\839,-516,451
        \\891,-625,532
        \\-652,-548,-490
        \\30,-46,-14
    ;

    var map = Map.init();
    defer map.deinit();
    // map.show();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    const largest = try map.find_largest_manhattan();
    try testing.expect(largest == 3621);
}
