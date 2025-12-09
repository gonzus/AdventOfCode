const std = @import("std");
const testing = std.testing;

pub const Module = struct {
    const V3 = struct {
        x: usize,
        y: usize,
        z: usize,

        pub fn init(str: []const u8) !V3 {
            var it = std.mem.tokenizeScalar(u8, str, ',');
            return .{
                .x = try std.fmt.parseUnsigned(usize, it.next().?, 10),
                .y = try std.fmt.parseUnsigned(usize, it.next().?, 10),
                .z = try std.fmt.parseUnsigned(usize, it.next().?, 10),
            };
        }

        fn delta2(l: usize, r: usize) usize {
            const li: isize = @intCast(l);
            const ri: isize = @intCast(r);
            const delta = li - ri;
            return @intCast(delta * delta);
        }

        fn distance(self: V3, other: V3) usize {
            return delta2(self.x, other.x) + delta2(self.y, other.y) + delta2(self.z, other.z);
        }
    };

    const Junction = struct {
        id: usize,
        pos: V3,
        parent: usize,
        size: usize,

        fn init(id: usize, pos: V3) Junction {
            return .{ .id = id, .pos = pos, .parent = id, .size = 1 };
        }

        fn compare(_: void, l: usize, r: usize) std.math.Order {
            return std.math.order(r, l);
        }
    };

    const Wire = struct {
        l: usize,
        r: usize,
        dist: usize,

        fn compare(_: void, l: Wire, r: Wire) std.math.Order {
            return std.math.order(l.dist, r.dist);
        }
    };

    alloc: std.mem.Allocator,
    junctions: std.ArrayList(Junction),
    last_product: usize,

    pub fn init(alloc: std.mem.Allocator) Module {
        return .{
            .alloc = alloc,
            .junctions = .empty,
            .last_product = 0,
        };
    }

    pub fn deinit(self: *Module) void {
        self.junctions.deinit(self.alloc);
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        const id = self.junctions.items.len;
        try self.junctions.append(self.alloc, Junction.init(id, try V3.init(line)));
    }

    pub fn computeJunctionProduct(self: *Module, wanted: usize) !usize {
        try self.mergeJunctions(wanted);
        return self.computeTopProduct(3);
    }

    pub fn computeLastProduct(self: *Module) !usize {
        try self.mergeJunctions(0);
        return self.last_product;
    }

    fn mergeJunctions(self: *Module, wanted: usize) !void {
        var pq = std.PriorityQueue(Wire, void, Wire.compare).init(self.alloc, {});
        defer pq.deinit();
        for (0..self.junctions.items.len) |l| {
            for (l + 1..self.junctions.items.len) |r| {
                const dist = self.junctions.items[l].pos.distance(self.junctions.items[r].pos);
                try pq.add(Wire{ .l = l, .r = r, .dist = dist });
            }
        }

        var connections: usize = 0;
        while (pq.count() > 0) {
            const w = pq.remove();
            self.junctionMerge(w.l, w.r);
            connections += 1;

            if (wanted > 0 and connections >= wanted) break;

            const any_root = self.junctions.items[self.junctionFind(w.l)];
            if (any_root.size < self.junctions.items.len) continue;

            const rl = self.junctions.items[w.l];
            const rr = self.junctions.items[w.r];
            self.last_product = rl.pos.x * rr.pos.x;
            break;
        }
    }

    fn computeTopProduct(self: *Module, top: usize) !usize {
        var seen = std.AutoHashMap(usize, void).init(self.alloc);
        defer seen.deinit();
        var pq = std.PriorityQueue(usize, void, Junction.compare).init(self.alloc, {});
        defer pq.deinit();
        for (self.junctions.items) |j| {
            const root_id = self.junctionFind(j.id);
            const gop = try seen.getOrPut(root_id);
            if (gop.found_existing) continue;
            const root = self.junctions.items[root_id];
            try pq.add(root.size);
        }
        var count: usize = 0;
        var prod: usize = 1;
        while (count < top and pq.count() > 0) : (count += 1) {
            const size = pq.remove();
            prod *= size;
        }
        return prod;
    }

    fn junctionFind(self: Module, id: usize) usize {
        var node = &self.junctions.items[id];
        while (node.parent != node.id) {
            const old_parent = node.parent;
            const parent = self.junctions.items[old_parent];
            node.parent = parent.parent;
            node = &self.junctions.items[old_parent];
        }
        return node.id;
    }

    fn junctionMerge(self: Module, l: usize, r: usize) void {
        const rl = self.junctionFind(l);
        const rr = self.junctionFind(r);
        if (rl == rr) return;

        var nl = &self.junctions.items[rl];
        var nr = &self.junctions.items[rr];
        if (nl.size < nr.size) {
            nr = &self.junctions.items[rl];
            nl = &self.junctions.items[rr];
        }

        nr.parent = nl.id; // Make x the new root
        nl.size += nr.size; // Update the size of x
    }
};

test "sample part 1" {
    const data =
        \\162,817,812
        \\57,618,57
        \\906,360,560
        \\592,479,940
        \\352,342,300
        \\466,668,158
        \\542,29,236
        \\431,825,988
        \\739,650,466
        \\52,470,668
        \\216,146,977
        \\819,987,18
        \\117,168,530
        \\805,96,715
        \\346,949,466
        \\970,615,88
        \\941,993,340
        \\862,61,35
        \\984,92,344
        \\425,690,689
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const product = try module.computeJunctionProduct(10);
    const expected = @as(usize, 40);
    try testing.expectEqual(expected, product);
}

test "sample part 2" {
    const data =
        \\162,817,812
        \\57,618,57
        \\906,360,560
        \\592,479,940
        \\352,342,300
        \\466,668,158
        \\542,29,236
        \\431,825,988
        \\739,650,466
        \\52,470,668
        \\216,146,977
        \\819,987,18
        \\117,168,530
        \\805,96,715
        \\346,949,466
        \\970,615,88
        \\941,993,340
        \\862,61,35
        \\984,92,344
        \\425,690,689
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const product = try module.computeLastProduct();
    const expected = @as(usize, 25272);
    try testing.expectEqual(expected, product);
}
