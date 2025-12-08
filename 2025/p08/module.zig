const std = @import("std");
const testing = std.testing;

pub const Module = struct {
    const INFINITY = std.math.maxInt(usize);

    const V3 = struct {
        const SIZE = 3;

        c: [SIZE]usize,

        pub fn init(str: []const u8) !V3 {
            var self: V3 = undefined;
            var p: usize = 0;
            var it = std.mem.tokenizeScalar(u8, str, ',');
            while (it.next()) |chunk| : (p += 1) {
                self.c[p] = try std.fmt.parseUnsigned(usize, chunk, 10);
            }
            return self;
        }

        fn dist(self: V3, other: V3) usize {
            var dst: usize = 0;
            for (0..SIZE) |p| {
                var delta: isize = 0;
                delta += @intCast(self.c[p]);
                delta -= @intCast(other.c[p]);
                const delta2: usize = @intCast(delta * delta);
                dst += delta2;
            }
            return dst;
        }
    };

    const Junction = struct {
        pos: V3,
        id: usize = INFINITY,
    };

    const Wire = struct {
        l: usize,
        r: usize,
        dst: usize,

        fn lessThan(_: void, l: Wire, r: Wire) bool {
            return l.dst < r.dst;
        }
    };

    const Circuits = struct {
        circuits: std.AutoHashMap(usize, usize),

        fn init(alloc: std.mem.Allocator) Circuits {
            return .{ .circuits = std.AutoHashMap(usize, usize).init(alloc) };
        }

        fn deinit(self: *Circuits) void {
            self.circuits.deinit();
        }

        fn addIdCount(self: *Circuits, id: usize, count: usize) !void {
            const gop = try self.circuits.getOrPut(id);
            if (!gop.found_existing) {
                gop.value_ptr.* = 0;
            }
            gop.value_ptr.* += count;
        }

        fn merge(self: *Circuits, l: usize, r: usize) !void {
            var sum: usize = 0;
            if (self.circuits.get(l)) |c| {
                sum += c;
            }
            if (self.circuits.get(r)) |c| {
                sum += c;
            }
            try self.circuits.put(l, 0);
            try self.circuits.put(r, sum);
        }

        fn getSortedCounts(self: Circuits, alloc: std.mem.Allocator, list: *std.ArrayList(usize)) !void {
            var it = self.circuits.iterator();
            while (it.next()) |e| {
                try list.append(alloc, e.value_ptr.*);
            }
            std.sort.heap(usize, list.items, {}, std.sort.desc(usize));
        }
    };

    alloc: std.mem.Allocator,
    junctions: std.ArrayList(Junction),

    pub fn init(alloc: std.mem.Allocator) Module {
        return .{
            .alloc = alloc,
            .junctions = .empty,
        };
    }

    pub fn deinit(self: *Module) void {
        self.junctions.deinit(self.alloc);
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        const j = Junction{
            .pos = try V3.init(line),
        };
        try self.junctions.append(self.alloc, j);
    }

    pub fn computeJunctionProduct(self: *Module, wanted: usize) !usize {
        var wires = std.ArrayList(Wire).empty;
        defer wires.deinit(self.alloc);
        for (0..self.junctions.items.len) |l| {
            for (l + 1..self.junctions.items.len) |r| {
                const dst = self.junctions.items[l].pos.dist(self.junctions.items[r].pos);
                try wires.append(self.alloc, Wire{ .l = l, .r = r, .dst = dst });
            }
        }
        std.sort.heap(Wire, wires.items, {}, Wire.lessThan);

        var circuits = Circuits.init(self.alloc);
        defer circuits.deinit();
        var remaining: usize = self.junctions.items.len;
        var last_product: usize = 0;
        var next_id: usize = 0;
        for (wires.items, 0..) |w, connections| {
            if (wanted > 0 and connections >= wanted) break;
            if (wanted == 0 and remaining == 0) return last_product;

            var wl = &self.junctions.items[w.l];
            var wr = &self.junctions.items[w.r];
            last_product = wl.pos.c[0] * wr.pos.c[0];

            if (wl.id == INFINITY and wr.id == INFINITY) {
                wl.id = next_id;
                wr.id = next_id;
                try circuits.addIdCount(next_id, 2);
                next_id += 1;
                remaining -= 2;
                continue;
            }
            if (wl.id == INFINITY) {
                wl.id = wr.id;
                try circuits.addIdCount(wr.id, 1);
                remaining -= 1;
                continue;
            }
            if (wr.id == INFINITY) {
                wr.id = wl.id;
                try circuits.addIdCount(wr.id, 1);
                remaining -= 1;
                continue;
            }
            if (wl.id != wr.id) {
                try circuits.merge(wl.id, wr.id);
                self.changeJunctionIds(wl.id, wr.id);
                continue;
            }
        }

        var counts = std.ArrayList(usize).empty;
        defer counts.deinit(self.alloc);
        try circuits.getSortedCounts(self.alloc, &counts);
        var prod: usize = 1;
        for (0..3) |p| {
            prod *= counts.items[p];
        }

        return prod;
    }

    fn changeJunctionIds(self: *Module, old: usize, new: usize) void {
        for (self.junctions.items) |*j| {
            if (j.id != old) continue;
            j.id = new;
        }
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

    const product = try module.computeJunctionProduct(0);
    const expected = @as(usize, 25272);
    try testing.expectEqual(expected, product);
}
