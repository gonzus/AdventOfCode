const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Fabric = struct {
    const Rectangle = Math.Rectangle;
    const Pos = Math.Pos2D;

    const Cut = struct {
        rect: Rectangle,
        overlaps: usize,

        pub fn init(rect: Rectangle) Cut {
            return .{
                .rect = rect,
                .overlaps = 0,
            };
        }
    };

    allocator: Allocator,
    cuts: std.ArrayList(Cut),

    pub fn init(allocator: Allocator) Fabric {
        return .{
            .allocator = allocator,
            .cuts = std.ArrayList(Cut).init(allocator),
        };
    }

    pub fn deinit(self: *Fabric) void {
        self.cuts.deinit();
    }

    pub fn addLine(self: *Fabric, line: []const u8) !void {
        var it = std.mem.tokenizeAny(u8, line, "# @,:x");
        const pos = self.cuts.items.len + 1;
        const id = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        if (id != pos) return error.InvalidId;
        const l = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        const t = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        const w = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        const h = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        const cut = Cut.init(Rectangle.initTLWH(t, l, w, h));
        try self.cuts.append(cut);
    }

    pub fn getOverlappingSquares(self: Fabric) !usize {
        var seen = std.AutoHashMap(Pos, void).init(self.allocator);
        defer seen.deinit();
        for (0..self.cuts.items.len) |p0| {
            const c0 = self.cuts.items[p0];
            for (p0 + 1..self.cuts.items.len) |p1| {
                const c1 = self.cuts.items[p1];
                const o = c0.rect.getOverlap(c1.rect);
                if (!o.isValid()) continue;
                for (o.tl.v[0]..o.br.v[0] + 1) |y| {
                    for (o.tl.v[1]..o.br.v[1] + 1) |x| {
                        _ = try seen.getOrPut(Pos.copy(&[_]usize{ x, y }));
                    }
                }
            }
        }
        return seen.count();
    }

    pub fn getNonOverlapping(self: Fabric) usize {
        for (0..self.cuts.items.len) |p0| {
            const c0 = &self.cuts.items[p0];
            for (p0 + 1..self.cuts.items.len) |p1| {
                const c1 = &self.cuts.items[p1];
                const o = c0.*.rect.getOverlap(c1.*.rect);
                if (!o.isValid()) continue;
                c0.*.overlaps += 1;
                c1.*.overlaps += 1;
            }
        }
        for (0..self.cuts.items.len) |p| {
            if (self.cuts.items[p].overlaps == 0) return p + 1;
        }
        return 0;
    }
};

test "sample part 1" {
    const data =
        \\#1 @ 1,3: 4x4
        \\#2 @ 3,1: 4x4
        \\#3 @ 5,5: 2x2
    ;

    var fabric = Fabric.init(testing.allocator);
    defer fabric.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try fabric.addLine(line);
    }

    const squares = try fabric.getOverlappingSquares();
    const expected = @as(usize, 4);
    try testing.expectEqual(expected, squares);
}

test "sample part 2" {
    const data =
        \\#1 @ 1,3: 4x4
        \\#2 @ 3,1: 4x4
        \\#3 @ 5,5: 2x2
    ;

    var fabric = Fabric.init(testing.allocator);
    defer fabric.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try fabric.addLine(line);
    }

    const id = fabric.getNonOverlapping();
    const expected = @as(usize, 3);
    try testing.expectEqual(expected, id);
}
