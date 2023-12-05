const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Almanac = struct {
    const Item = enum {
        seed,
        soil,
        fertilizer,
        water,
        light,
        temperature,
        humidity,

        pub fn parse(str: []const u8) !Item {
            if (std.mem.eql(u8, str, "seed")) return .seed;
            if (std.mem.eql(u8, str, "soil")) return .soil;
            if (std.mem.eql(u8, str, "fertilizer")) return .fertilizer;
            if (std.mem.eql(u8, str, "water")) return .water;
            if (std.mem.eql(u8, str, "light")) return .light;
            if (std.mem.eql(u8, str, "temperature")) return .temperature;
            if (std.mem.eql(u8, str, "humidity")) return .humidity;
            return error.InvalidItem;
        }
    };

    const ALL_ITEMS = [_]Item{
        .seed,
        .soil,
        .fertilizer,
        .water,
        .light,
        .temperature,
        .humidity,
    };

    const Range = struct {
        beg: isize,
        end: isize,

        pub fn initFromBegEnd(beg: isize, end: isize) !Range {
            if (beg > end) return error.RangeBegGreaterThanEnd;
            var self = Range{
                .beg = beg,
                .end = end,
            };
            return self;
        }

        pub fn initFromBegLen(beg: isize, len: isize) !Range {
            return try Range.initFromBegEnd(beg, beg + @as(isize, @intCast(len)) - 1);
        }

        pub fn initFromNums(num: [2]isize) !Range {
            return try Range.initFromBegLen(num[0], num[1]);
        }

        pub fn lessThan(_: void, l: Range, r: Range) bool {
            return l.beg < r.beg;
        }

        pub fn contains(self: Range, num: isize) bool {
            return (num >= self.beg and num <= self.end);
        }
    };

    const Map = struct {
        range: Range,
        delta: isize,

        pub fn initFromNums(num: [3]isize) !Map {
            var self = Map{
                .range = try Range.initFromBegLen(num[1], num[2]),
                .delta = num[0] - num[1],
            };
            return self;
        }

        pub fn initFromRangeDelta(range: Range, delta: isize) Map {
            var self = Map{
                .range = range,
                .delta = delta,
            };
            return self;
        }

        pub fn lessThan(_: void, l: Map, r: Map) bool {
            return Range.lessThan({}, l.range, r.range);
        }

        pub fn getTargetRange(self: Map) !Range {
            return try Range.initFromBegEnd(self.range.beg + self.delta, self.range.end + self.delta);
        }
    };
    const Maps = std.ArrayList(Map);

    allocator: Allocator,
    use_seed_ranges: bool,
    item_pos: usize,
    seed_ranges: std.ArrayList(Range),
    mappings: std.AutoHashMap(Item, Maps),

    pub fn init(allocator: Allocator, use_seed_ranges: bool) Almanac {
        var self = Almanac{
            .allocator = allocator,
            .use_seed_ranges = use_seed_ranges,
            .item_pos = 0,
            .seed_ranges = std.ArrayList(Range).init(allocator),
            .mappings = std.AutoHashMap(Item, Maps).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Almanac) void {
        var it = self.mappings.valueIterator();
        while (it.next()) |mapping| {
            mapping.deinit();
        }
        self.mappings.deinit();
        self.seed_ranges.deinit();
    }

    pub fn addLine(self: *Almanac, line: []const u8) !void {
        if (line.len == 0) {
            return;
        }

        if (std.ascii.isDigit(line.ptr[0])) {
            // mapping from source to destination
            const source = ALL_ITEMS[self.item_pos];
            var entry = try self.mappings.getOrPut(source);
            if (!entry.found_existing) {
                entry.value_ptr.* = Maps.init(self.allocator);
            }
            var map = entry.value_ptr;
            var nums: [3]isize = undefined;
            var num_pos: usize = 0;
            var number_it = std.mem.tokenizeScalar(u8, line, ' ');
            while (number_it.next()) |n| : (num_pos += 1) {
                nums[num_pos] = try std.fmt.parseUnsigned(isize, n, 10);
            }
            if (num_pos != 3) return error.InvalidMap;
            try map.append(try Map.initFromNums(nums));
            return;
        }

        var chunk_it = std.mem.tokenizeScalar(u8, line, ':');
        const left_chunk = chunk_it.next().?;
        if (chunk_it.next()) |right_chunk| {
            // seeds definition
            if (!std.mem.eql(u8, left_chunk, "seeds")) return error.InvalidLeftChunk;
            var number_it = std.mem.tokenizeScalar(u8, right_chunk, ' ');
            var num_pos: usize = 0;
            var nums: [2]isize = undefined;
            while (number_it.next()) |n| {
                const s = try std.fmt.parseUnsigned(isize, n, 10);
                if (self.use_seed_ranges) {
                    nums[num_pos] = s;
                    num_pos += 1;
                    if (num_pos == 2) {
                        _ = try self.seed_ranges.append(try Range.initFromNums(nums));
                        num_pos = 0;
                    }
                } else {
                    _ = try self.seed_ranges.append(try Range.initFromBegEnd(s, s));
                }
            }
            return;
        }

        // mapping definition
        if (std.mem.eql(u8, left_chunk, "seeds")) return error.InvalidLeftChunk;
        var aspect_it = std.mem.tokenizeScalar(u8, left_chunk, '-');
        const item = try Item.parse(aspect_it.next().?);
        self.item_pos = try getItemPos(item);
    }

    pub fn getLowestLocation(self: *Almanac) !isize {
        var a = Maps.init(self.allocator);
        defer a.deinit();
        for (self.seed_ranges.items) |range| {
            try a.append(Map.initFromRangeDelta(range, 0));
        }

        var merged = Maps.init(self.allocator);
        defer merged.deinit();

        var item_pos: usize = 0;
        while (item_pos < ALL_ITEMS.len) : (item_pos += 1) {
            var b = self.mappings.get(ALL_ITEMS[item_pos]).?;
            std.sort.heap(Map, b.items, {}, Map.lessThan);
            try self.mergeTransitiveMap(&merged, a, b);
            a.deinit();
            a = try merged.clone();
        }

        var lowest: isize = std.math.maxInt(isize);
        for (merged.items) |m| {
            const value = m.range.beg + m.delta;
            if (lowest > value) {
                lowest = value;
            }
        }
        return lowest;
    }

    fn getItemPos(item: Item) !usize {
        for (ALL_ITEMS, 0..) |source, pos| {
            if (source == item) {
                return pos;
            }
        }
        return error.InvalidItem;
    }

    fn mergeTransitiveMap(self: Almanac, target: *Maps, a2b: Maps, b2c: Maps) !void {
        target.clearRetainingCapacity();

        var tmp = std.ArrayList(Range).init(self.allocator);
        defer tmp.deinit();
        for (a2b.items) |a| {
            const ra = try a.getTargetRange();
            try tmp.append(ra);
        }
        std.sort.heap(Range, tmp.items, {}, Range.lessThan);

        var a_pos: usize = 0;
        var b_pos: usize = 0;
        while (true) {
            if (a_pos >= tmp.items.len and b_pos >= b2c.items.len) {
                break;
            }
            if (a_pos >= tmp.items.len) {
                break;
            }
            if (b_pos >= b2c.items.len) {
                const r = tmp.items[a_pos];
                const m = Map.initFromRangeDelta(r, 0);
                a_pos += 1;
                try target.append(m);
                continue;
            }

            const ra = tmp.items[a_pos];
            const la = Map.initFromRangeDelta(ra, 0);
            const lb = b2c.items[b_pos];
            const rb = lb.range;
            if (ra.end < rb.beg) {
                a_pos += 1;
                try target.append(la);
                continue;
            }
            if (ra.beg > rb.end) {
                b_pos += 1;
                continue;
            }
            if (ra.beg < rb.beg) {
                const r = try Range.initFromBegEnd(ra.beg, @min(ra.end, rb.beg - 1));
                const m = Map.initFromRangeDelta(r, la.delta);
                try target.append(m);
            } else {}
            {
                const l = @max(ra.beg, rb.beg);
                const h = @min(ra.end, rb.end);
                if (l <= h) {
                    const r = try Range.initFromBegEnd(l, h);
                    const m = Map.initFromRangeDelta(r, lb.delta);
                    try target.append(m);
                }
            }
            if (ra.end > rb.end) {
                const nb = (if (ra.beg > rb.end) ra.beg else rb.end) + 1;
                tmp.items[a_pos].beg = nb - la.delta;
                b_pos += 1;
            } else if (ra.end < rb.end) {
                const nb = ra.end + 1;
                b2c.items[b_pos].range.beg = nb;
                a_pos += 1;
            } else {
                a_pos += 1;
                b_pos += 1;
            }
        }
    }
};

test "sample part 1" {
    const data =
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
    ;

    var almanac = Almanac.init(std.testing.allocator, false);
    defer almanac.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try almanac.addLine(line);
    }

    const location = try almanac.getLowestLocation();
    const expected = @as(isize, 35);
    try testing.expectEqual(expected, location);
}

test "sample part 2" {
    const data =
        \\seeds: 79 14 55 13
        \\
        \\seed-to-soil map:
        \\50 98 2
        \\52 50 48
        \\
        \\soil-to-fertilizer map:
        \\0 15 37
        \\37 52 2
        \\39 0 15
        \\
        \\fertilizer-to-water map:
        \\49 53 8
        \\0 11 42
        \\42 0 7
        \\57 7 4
        \\
        \\water-to-light map:
        \\88 18 7
        \\18 25 70
        \\
        \\light-to-temperature map:
        \\45 77 23
        \\81 45 19
        \\68 64 13
        \\
        \\temperature-to-humidity map:
        \\0 69 1
        \\1 0 69
        \\
        \\humidity-to-location map:
        \\60 56 37
        \\56 93 4
    ;

    var almanac = Almanac.init(std.testing.allocator, true);
    defer almanac.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try almanac.addLine(line);
    }

    const location = try almanac.getLowestLocation();
    const expected = @as(isize, 46);
    try testing.expectEqual(expected, location);
}
