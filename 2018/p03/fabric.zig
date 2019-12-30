const std = @import("std");
const assert = std.debug.assert;

pub const Fabric = struct {
    pub const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            return Pos{
                .x = x,
                .y = y,
            };
        }
    };

    pub const Cut = struct {
        pmin: Pos,
        pmax: Pos,

        pub fn init(pmin: Pos, pmax: Pos) Cut {
            return Cut{
                .pmin = pmin,
                .pmax = pmax,
            };
        }
    };

    cells: std.AutoHashMap(Pos, usize),
    cuts: std.AutoHashMap(usize, Cut),
    pmin: Pos,
    pmax: Pos,
    imin: usize,
    imax: usize,

    pub fn init() Fabric {
        const allocator = std.heap.direct_allocator;
        return Fabric{
            .cells = std.AutoHashMap(Pos, usize).init(allocator),
            .cuts = std.AutoHashMap(usize, Cut).init(allocator),
            .pmin = Pos.init(std.math.maxInt(usize), std.math.maxInt(usize)),
            .pmax = Pos.init(0, 0),
            .imin = 0,
            .imax = 0,
        };
    }

    pub fn deinit(self: *Fabric) void {
        self.cuts.deinit();
        self.cells.deinit();
    }

    pub fn add_cut(self: *Fabric, line: []const u8) void {
        // std.debug.warn("CUT [{}]\n", line);
        var cut: Cut = undefined;
        var id: usize = 0;
        var r: usize = 0;
        var itc = std.mem.separate(line, " ");
        while (itc.next()) |piece| {
            r += 1;
            if (r == 1) {
                id = std.fmt.parseInt(usize, piece[1..], 10) catch 0;
                if (self.imin > id) self.imin = id;
                if (self.imax < id) self.imax = id;
                continue;
            }
            if (r == 3) {
                var q: usize = 0;
                var itp = std.mem.separate(piece[0 .. piece.len - 1], ",");
                while (itp.next()) |str| {
                    q += 1;
                    const v = std.fmt.parseInt(usize, str, 10) catch 0;
                    if (q == 1) {
                        cut.pmin.x = v;
                        if (self.pmin.x > cut.pmin.x) self.pmin.x = cut.pmin.x;
                        continue;
                    }
                    if (q == 2) {
                        cut.pmin.y = v;
                        if (self.pmin.y > cut.pmin.y) self.pmin.y = cut.pmin.y;
                        continue;
                    }
                }
            }
            if (r == 4) {
                var q: usize = 0;
                var itp = std.mem.separate(piece, "x");
                while (itp.next()) |str| {
                    q += 1;
                    const v = std.fmt.parseInt(usize, str, 10) catch 0;
                    if (q == 1) {
                        cut.pmax.x = cut.pmin.x + v - 1;
                        if (self.pmax.x < cut.pmax.x) self.pmax.x = cut.pmax.x;
                        continue;
                    }
                    if (q == 2) {
                        cut.pmax.y = cut.pmin.y + v - 1;
                        if (self.pmax.y < cut.pmax.y) self.pmax.y = cut.pmax.y;
                        continue;
                    }
                }
            }
        }
        _ = self.cuts.put(id, cut) catch unreachable;

        // std.debug.warn("CUT => {} {} {} {} {}\n", id, cut.pmin.x, cut.pmin.y, cut.pmax.x, cut.pmax.y);
        var x: usize = cut.pmin.x;
        while (x <= cut.pmax.x) : (x += 1) {
            var y: usize = cut.pmin.y;
            while (y <= cut.pmax.y) : (y += 1) {
                var c: usize = 0;
                const p = Pos.init(x, y);
                if (self.cells.contains(p)) {
                    c = self.cells.get(p).?.value;
                }
                c += 1;
                _ = self.cells.put(p, c) catch unreachable;
            }
        }
    }

    pub fn count_overlaps(self: *Fabric) usize {
        // std.debug.warn("BOARD => {} {} {} {}\n", self.pmin.x, self.pmin.y, self.pmax.x, self.pmax.y);
        var count: usize = 0;
        var x: usize = self.pmin.x;
        while (x <= self.pmax.x) : (x += 1) {
            var y: usize = self.pmin.y;
            while (y <= self.pmax.y) : (y += 1) {
                const p = Pos.init(x, y);
                if (!self.cells.contains(p)) continue;
                var c = self.cells.get(p).?.value;
                if (c > 1) count += 1;
            }
        }
        return count;
    }

    pub fn find_non_overlapping(self: *Fabric) usize {
        const allocator = std.heap.direct_allocator;
        var bad = std.AutoHashMap(usize, void).init(allocator);
        defer bad.deinit();

        var id: usize = 0;
        var j: usize = self.imin;
        while (j <= self.imax) : (j += 1) {
            if (!self.cuts.contains(j)) continue;
            if (bad.contains(j)) continue;
            const c0 = self.cuts.get(j).?.value;
            var ok: bool = true;
            var k: usize = 0;
            while (k <= self.imax) : (k += 1) {
                if (j == k) continue;
                if (!self.cuts.contains(k)) continue;
                const c1 = self.cuts.get(k).?.value;
                if ((c0.pmin.x > c1.pmax.x) or
                    (c0.pmax.x < c1.pmin.x) or
                    (c0.pmin.y > c1.pmax.y) or
                    (c0.pmax.y < c1.pmin.y))
                {
                    continue;
                }
                // std.debug.warn("OVERLAP {} {}\n", j, k);
                ok = false;
                _ = bad.put(k, {}) catch unreachable;
                break;
            }
            if (!ok) {
                continue;
            }
            // std.debug.warn("FOUND {}: {} {} {} {}\n", j, c0.pmin.x, c0.pmin.y, c0.pmax.y, c0.pmax.y);
            id = j;
        }
        return id;
    }
};

test "simple cuts" {
    const data =
        \\#1 @ 1,3: 4x4
        \\#2 @ 3,1: 4x4
        \\#3 @ 5,5: 2x2
    ;

    var fabric = Fabric.init();
    defer fabric.deinit();

    var it = std.mem.separate(data, "\n");
    while (it.next()) |line| {
        fabric.add_cut(line);
    }
    const output = fabric.count_overlaps();
    assert(output == 4);
}

test "simple non-overlapping" {
    const data =
        \\#1 @ 1,3: 4x4
        \\#2 @ 3,1: 4x4
        \\#3 @ 5,5: 2x2
    ;

    var fabric = Fabric.init();
    defer fabric.deinit();

    var it = std.mem.separate(data, "\n");
    while (it.next()) |line| {
        fabric.add_cut(line);
    }
    const output = fabric.find_non_overlapping();
    assert(output == 3);
}
