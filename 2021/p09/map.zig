const std = @import("std");
const testing = std.testing;
const allocator = std.testing.allocator;

const desc_usize = std.sort.desc(usize);

pub const Map = struct {
    const Pos = struct {
        x: isize,
        y: isize,

        pub fn init(x: isize, y: isize) Pos {
            var self = Pos{ .x = x, .y = y };
            return self;
        }
    };

    width: usize,
    height: usize,
    data: std.AutoHashMap(Pos, usize),
    seen: std.AutoHashMap(Pos, void),

    pub fn init() Map {
        var self = Map{
            .width = 0,
            .height = 0,
            .data = std.AutoHashMap(Pos, usize).init(allocator),
            .seen = std.AutoHashMap(Pos, void).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.seen.deinit();
        self.data.deinit();
    }

    pub fn process_line(self: *Map, data: []const u8) !void {
        if (self.width == 0) {
            self.width = data.len;
        }
        if (self.width != data.len) {
            return error.ChangingWidth;
        }
        const sy = @intCast(isize, self.height);
        for (data) |num, x| {
            const sx = @intCast(isize, x);
            const p = Pos.init(sx, sy);
            const n = num - '0';
            try self.data.put(p, n);
        }
        self.height += 1;
    }

    pub fn get_total_risk(self: Map) usize {
        var risk: usize = 0;
        var x: isize = 0;
        while (x < self.width) : (x += 1) {
            var y: isize = 0;
            while (y < self.height) : (y += 1) {
                if (!self.is_basin(x, y)) continue;
                risk += 1 + self.get_height(x, y);
            }
        }
        return risk;
    }

    pub fn get_largest_n_basins_product(self: *Map, n: usize) !usize {
        var sizes = std.ArrayList(usize).init(allocator);
        defer sizes.deinit();

        self.seen.clearRetainingCapacity();
        var x: isize = 0;
        while (x < self.width) : (x += 1) {
            var y: isize = 0;
            while (y < self.height) : (y += 1) {
                if (!self.is_basin(x, y)) continue;

                const size = try self.walk_basin(x, y);
                if (size == 0) continue;

                sizes.append(size) catch unreachable;
            }
        }

        std.sort.sort(usize, sizes.items, {}, desc_usize);
        var product: usize = 1;
        for (sizes.items[0..n]) |s| {
            product *= s;
        }
        return product;
    }

    fn get_height(self: Map, x: isize, y: isize) usize {
        const p = Pos.init(x, y);
        return self.data.get(p) orelse std.math.maxInt(usize);
    }

    fn is_basin(self: Map, x: isize, y: isize) bool {
        var h = self.get_height(x, y);
        if (h >= self.get_height(x - 1, y)) return false;
        if (h >= self.get_height(x + 1, y)) return false;
        if (h >= self.get_height(x, y - 1)) return false;
        if (h >= self.get_height(x, y + 1)) return false;
        return true;
    }

    fn walk_basin(self: *Map, x: isize, y: isize) !usize {
        const p = Pos.init(x, y);
        if (self.seen.contains(p)) return 0;

        self.seen.put(p, {}) catch unreachable;
        var size: usize = 1;
        size += try self.walk_neighbors(x - 1, y);
        size += try self.walk_neighbors(x + 1, y);
        size += try self.walk_neighbors(x, y - 1);
        size += try self.walk_neighbors(x, y + 1);
        return size;
    }

    const WalkErrors = error{OutOfMemory};

    fn walk_neighbors(self: *Map, x: isize, y: isize) WalkErrors!usize {
        const p = Pos.init(x, y);
        if (self.seen.contains(p)) return 0;
        if (!self.data.contains(p)) return 0;

        const h = self.get_height(x, y);
        if (h == 9) return 0;

        try self.seen.put(p, {});
        var size: usize = 1;
        if (h < self.get_height(x - 1, y)) size += try self.walk_neighbors(x - 1, y);
        if (h < self.get_height(x + 1, y)) size += try self.walk_neighbors(x + 1, y);
        if (h < self.get_height(x, y - 1)) size += try self.walk_neighbors(x, y - 1);
        if (h < self.get_height(x, y + 1)) size += try self.walk_neighbors(x, y + 1);
        return size;
    }
};

test "sample part a" {
    const data: []const u8 =
        \\2199943210
        \\3987894921
        \\9856789892
        \\8767896789
        \\9899965678
    ;

    var map = Map.init();
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    const risk = map.get_total_risk();
    try testing.expect(risk == 15);
}

test "sample part b" {
    const data: []const u8 =
        \\2199943210
        \\3987894921
        \\9856789892
        \\8767896789
        \\9899965678
    ;

    var map = Map.init();
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.process_line(line);
    }
    const product = try map.get_largest_n_basins_product(3);
    try testing.expect(product == 1134);
}
