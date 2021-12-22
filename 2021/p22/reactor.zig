const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

pub const Reactor = struct {
    const BoxList = std.ArrayList(Box);

    pub const Pos = struct {
        x: isize,
        y: isize,
        z: isize,

        pub fn init(x: isize, y: isize, z: isize) Pos {
            var self = Pos{ .x = x, .y = y, .z = z };
            return self;
        }
    };

    const Box = struct {
        min: Pos,
        max: Pos,

        pub fn init(min: Pos, max: Pos) Box {
            var self = Box{ .min = min, .max = max };
            return self;
        }

        pub fn volume(self: Box) usize {
            var vol: usize = 1;
            vol *= @intCast(usize, self.max.x - self.min.x) + 1;
            vol *= @intCast(usize, self.max.y - self.min.y) + 1;
            vol *= @intCast(usize, self.max.z - self.min.z) + 1;
            return vol;
        }

        pub fn clipped_volume(self: Box, clip: Box) usize {
            if (self.min.x > clip.max.x or self.min.y > clip.max.y or self.min.z > clip.max.z) return 0;
            if (self.max.x < clip.min.x or self.max.y < clip.min.y or self.max.z < clip.min.z) return 0;
            return self.volume();
        }

        pub fn intersects(self: Box, other: Box) bool {
            if (self.max.x < other.min.x or other.max.x < self.min.x) return false;
            if (self.max.y < other.min.y or other.max.y < self.min.y) return false;
            if (self.max.z < other.min.z or other.max.z < self.min.z) return false;
            return true;
        }

        pub fn subtract(b0: Box, b1: Box, list: *BoxList) !void {
            var min = Pos.init(
                if (b0.min.x > b1.min.x) b0.min.x else b1.min.x,
                if (b0.min.y > b1.min.y) b0.min.y else b1.min.y,
                if (b0.min.z > b1.min.z) b0.min.z else b1.min.z,
            );
            var max = Pos.init(
                if (b0.max.x < b1.max.x) b0.max.x else b1.max.x,
                if (b0.max.y < b1.max.y) b0.max.y else b1.max.y,
                if (b0.max.z < b1.max.z) b0.max.z else b1.max.z,
            );
            var b2 = Box.init(min, max);
            if (b0.min.z < b2.min.z) try list.append(Box.init(Pos.init(b0.min.x, b0.min.y, b0.min.z), Pos.init(b0.max.x, b0.max.y, b2.min.z - 1)));
            if (b2.max.z < b0.max.z) try list.append(Box.init(Pos.init(b0.min.x, b0.min.y, b2.max.z + 1), Pos.init(b0.max.x, b0.max.y, b0.max.z)));
            if (b0.min.x < b2.min.x) try list.append(Box.init(Pos.init(b0.min.x, b0.min.y, b2.min.z), Pos.init(b2.min.x - 1, b0.max.y, b2.max.z)));
            if (b2.max.x < b0.max.x) try list.append(Box.init(Pos.init(b2.max.x + 1, b0.min.y, b2.min.z), Pos.init(b0.max.x, b0.max.y, b2.max.z)));
            if (b0.min.y < b2.min.y) try list.append(Box.init(Pos.init(b2.min.x, b0.min.y, b2.min.z), Pos.init(b2.max.x, b2.min.y - 1, b2.max.z)));
            if (b2.max.y < b0.max.y) try list.append(Box.init(Pos.init(b2.min.x, b2.max.y + 1, b2.min.z), Pos.init(b2.max.x, b0.max.y, b2.max.z)));
        }
    };

    const Cube = struct {
        on: bool,
        box: Box,

        pub fn init(on: bool, box: Box) Cube {
            var self = Cube{ .on = on, .box = box };
            return self;
        }
    };

    cubes: std.ArrayList(Cube),
    clip: Box,

    pub fn init() Reactor {
        var self = Reactor{
            .cubes = std.ArrayList(Cube).init(allocator),
            .clip = Box.init(
                Pos.init(std.math.minInt(isize), std.math.minInt(isize), std.math.minInt(isize)),
                Pos.init(std.math.maxInt(isize), std.math.maxInt(isize), std.math.maxInt(isize)),
            ),
        };
        return self;
    }

    pub fn deinit(self: *Reactor) void {
        self.cubes.deinit();
    }

    pub fn set_clip_cube(self: *Reactor, side: usize) void {
        const s = @intCast(isize, side);
        const min = -s;
        const max = s;
        self.clip = Box.init(Pos.init(min, min, min), Pos.init(max, max, max));
    }

    pub fn process_line(self: *Reactor, data: []const u8) !void {
        var on: bool = false;
        var p_space: usize = 0;
        var it_space = std.mem.split(u8, data, " ");
        while (it_space.next()) |str| : (p_space += 1) {
            if (p_space == 0) {
                if (std.mem.eql(u8, str, "on")) {
                    on = true;
                    continue;
                }
                if (std.mem.eql(u8, str, "off")) {
                    on = false;
                    continue;
                }
                unreachable;
            }
            if (p_space == 1) {
                var box: Box = undefined;
                var pos_comma: usize = 0;
                var it_comma = std.mem.split(u8, str, ",");
                while (it_comma.next()) |range| : (pos_comma += 1) {
                    self.parse_min_max(range, &box);
                }
                var cube = Cube.init(on, box);
                try self.cubes.append(cube);
                continue;
            }
            unreachable;
        }
    }

    pub fn run_reboot(self: *Reactor) !usize {
        var boxes = BoxList.init(allocator);
        defer boxes.deinit();

        for (self.cubes.items) |c| {
            var list = BoxList.init(allocator);
            defer list.deinit();

            for (boxes.items) |b| {
                if (b.intersects(c.box)) {
                    try b.subtract(c.box, &list);
                } else {
                    try list.append(b);
                }
            }
            if (c.on) {
                try list.append(c.box);
            }

            boxes.clearRetainingCapacity();
            try boxes.appendSlice(list.items);
        }

        var count: usize = 0;
        for (boxes.items) |c| {
            count += c.clipped_volume(self.clip);
        }
        return count;
    }

    fn parse_min_max(_: *Reactor, range: []const u8, box: *Box) void {
        // std.debug.warn("PARSE {c}\n", .{range});
        var axis: u8 = undefined;
        var pos_eq: usize = 0;
        var it_eq = std.mem.split(u8, range, "=");
        while (it_eq.next()) |definition| : (pos_eq += 1) {
            if (pos_eq == 0) {
                axis = definition[0];
                continue;
            }
            var pos_dots: usize = 0;
            var it_dots = std.mem.split(u8, definition, "..");
            while (it_dots.next()) |limit| : (pos_dots += 1) {
                if (pos_dots == 0) {
                    const min = std.fmt.parseInt(isize, limit, 10) catch unreachable;
                    if (axis == 'x') box.*.min.x = min;
                    if (axis == 'y') box.*.min.y = min;
                    if (axis == 'z') box.*.min.z = min;
                    continue;
                }
                if (pos_dots == 1) {
                    const max = std.fmt.parseInt(isize, limit, 10) catch unreachable;
                    if (axis == 'x') box.*.max.x = max;
                    if (axis == 'y') box.*.max.y = max;
                    if (axis == 'z') box.*.max.z = max;
                    continue;
                }
                unreachable;
            }
        }
    }
};

test "sample part a small" {
    const data: []const u8 =
        \\on x=10..12,y=10..12,z=10..12
        \\on x=11..13,y=11..13,z=11..13
        \\off x=9..11,y=9..11,z=9..11
        \\on x=10..10,y=10..10,z=10..10
    ;

    var reactor = Reactor.init();
    defer reactor.deinit();
    reactor.set_clip_cube(50);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try reactor.process_line(line);
    }

    const cubes = try reactor.run_reboot();
    try testing.expect(cubes == 39);
}

test "sample part a large" {
    const data: []const u8 =
        \\on x=-20..26,y=-36..17,z=-47..7
        \\on x=-20..33,y=-21..23,z=-26..28
        \\on x=-22..28,y=-29..23,z=-38..16
        \\on x=-46..7,y=-6..46,z=-50..-1
        \\on x=-49..1,y=-3..46,z=-24..28
        \\on x=2..47,y=-22..22,z=-23..27
        \\on x=-27..23,y=-28..26,z=-21..29
        \\on x=-39..5,y=-6..47,z=-3..44
        \\on x=-30..21,y=-8..43,z=-13..34
        \\on x=-22..26,y=-27..20,z=-29..19
        \\off x=-48..-32,y=26..41,z=-47..-37
        \\on x=-12..35,y=6..50,z=-50..-2
        \\off x=-48..-32,y=-32..-16,z=-15..-5
        \\on x=-18..26,y=-33..15,z=-7..46
        \\off x=-40..-22,y=-38..-28,z=23..41
        \\on x=-16..35,y=-41..10,z=-47..6
        \\off x=-32..-23,y=11..30,z=-14..3
        \\on x=-49..-5,y=-3..45,z=-29..18
        \\off x=18..30,y=-20..-8,z=-3..13
        \\on x=-41..9,y=-7..43,z=-33..15
        \\on x=-54112..-39298,y=-85059..-49293,z=-27449..7877
        \\on x=967..23432,y=45373..81175,z=27513..53682
    ;

    var reactor = Reactor.init();
    defer reactor.deinit();
    reactor.set_clip_cube(50);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try reactor.process_line(line);
    }

    const cubes = try reactor.run_reboot();
    try testing.expect(cubes == 590784);
}

test "sample part b" {
    const data: []const u8 =
        \\on x=-5..47,y=-31..22,z=-19..33
        \\on x=-44..5,y=-27..21,z=-14..35
        \\on x=-49..-1,y=-11..42,z=-10..38
        \\on x=-20..34,y=-40..6,z=-44..1
        \\off x=26..39,y=40..50,z=-2..11
        \\on x=-41..5,y=-41..6,z=-36..8
        \\off x=-43..-33,y=-45..-28,z=7..25
        \\on x=-33..15,y=-32..19,z=-34..11
        \\off x=35..47,y=-46..-34,z=-11..5
        \\on x=-14..36,y=-6..44,z=-16..29
        \\on x=-57795..-6158,y=29564..72030,z=20435..90618
        \\on x=36731..105352,y=-21140..28532,z=16094..90401
        \\on x=30999..107136,y=-53464..15513,z=8553..71215
        \\on x=13528..83982,y=-99403..-27377,z=-24141..23996
        \\on x=-72682..-12347,y=18159..111354,z=7391..80950
        \\on x=-1060..80757,y=-65301..-20884,z=-103788..-16709
        \\on x=-83015..-9461,y=-72160..-8347,z=-81239..-26856
        \\on x=-52752..22273,y=-49450..9096,z=54442..119054
        \\on x=-29982..40483,y=-108474..-28371,z=-24328..38471
        \\on x=-4958..62750,y=40422..118853,z=-7672..65583
        \\on x=55694..108686,y=-43367..46958,z=-26781..48729
        \\on x=-98497..-18186,y=-63569..3412,z=1232..88485
        \\on x=-726..56291,y=-62629..13224,z=18033..85226
        \\on x=-110886..-34664,y=-81338..-8658,z=8914..63723
        \\on x=-55829..24974,y=-16897..54165,z=-121762..-28058
        \\on x=-65152..-11147,y=22489..91432,z=-58782..1780
        \\on x=-120100..-32970,y=-46592..27473,z=-11695..61039
        \\on x=-18631..37533,y=-124565..-50804,z=-35667..28308
        \\on x=-57817..18248,y=49321..117703,z=5745..55881
        \\on x=14781..98692,y=-1341..70827,z=15753..70151
        \\on x=-34419..55919,y=-19626..40991,z=39015..114138
        \\on x=-60785..11593,y=-56135..2999,z=-95368..-26915
        \\on x=-32178..58085,y=17647..101866,z=-91405..-8878
        \\on x=-53655..12091,y=50097..105568,z=-75335..-4862
        \\on x=-111166..-40997,y=-71714..2688,z=5609..50954
        \\on x=-16602..70118,y=-98693..-44401,z=5197..76897
        \\on x=16383..101554,y=4615..83635,z=-44907..18747
        \\off x=-95822..-15171,y=-19987..48940,z=10804..104439
        \\on x=-89813..-14614,y=16069..88491,z=-3297..45228
        \\on x=41075..99376,y=-20427..49978,z=-52012..13762
        \\on x=-21330..50085,y=-17944..62733,z=-112280..-30197
        \\on x=-16478..35915,y=36008..118594,z=-7885..47086
        \\off x=-98156..-27851,y=-49952..43171,z=-99005..-8456
        \\off x=2032..69770,y=-71013..4824,z=7471..94418
        \\on x=43670..120875,y=-42068..12382,z=-24787..38892
        \\off x=37514..111226,y=-45862..25743,z=-16714..54663
        \\off x=25699..97951,y=-30668..59918,z=-15349..69697
        \\off x=-44271..17935,y=-9516..60759,z=49131..112598
        \\on x=-61695..-5813,y=40978..94975,z=8655..80240
        \\off x=-101086..-9439,y=-7088..67543,z=33935..83858
        \\off x=18020..114017,y=-48931..32606,z=21474..89843
        \\off x=-77139..10506,y=-89994..-18797,z=-80..59318
        \\off x=8476..79288,y=-75520..11602,z=-96624..-24783
        \\on x=-47488..-1262,y=24338..100707,z=16292..72967
        \\off x=-84341..13987,y=2429..92914,z=-90671..-1318
        \\off x=-37810..49457,y=-71013..-7894,z=-105357..-13188
        \\off x=-27365..46395,y=31009..98017,z=15428..76570
        \\off x=-70369..-16548,y=22648..78696,z=-1892..86821
        \\on x=-53470..21291,y=-120233..-33476,z=-44150..38147
        \\off x=-93533..-4276,y=-16170..68771,z=-104985..-24507
    ;

    var reactor = Reactor.init();
    defer reactor.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try reactor.process_line(line);
    }

    const cubes = try reactor.run_reboot();
    try testing.expect(cubes == 2758514936282235);
}
