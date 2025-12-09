const std = @import("std");
const testing = std.testing;

pub const Module = struct {
    const Point = struct {
        x: isize,
        y: isize,

        pub fn init(x: isize, y: isize) Point {
            return .{ .x = x, .y = y };
        }
    };

    const Line = struct {
        l: Point,
        r: Point,

        pub fn init(l: Point, r: Point) Line {
            return .{ .l = l, .r = r };
        }

        pub fn initContaining(l: Point, r: Point) Line {
            const minx = @min(l.x, r.x);
            const miny = @min(l.y, r.y);
            const maxx = @max(l.x, r.x);
            const maxy = @max(l.y, r.y);
            return Line.init(Point.init(minx, miny), Point.init(maxx, maxy));
        }

        pub fn areaSurroundedAsDiagonal(diagonal: Line) usize {
            // diagonal represents opposite corners of a rectangle
            const w: usize = @intCast(@abs(diagonal.r.x - diagonal.l.x) + 1);
            const h: usize = @intCast(@abs(diagonal.r.y - diagonal.l.y) + 1);
            return w * h;
        }

        pub fn outsideDiagonal(border: Line, diagonal: Line) bool {
            // assumes diagonal and border are "ordered", as per initContaining()
            if (border.l.x >= diagonal.r.x) return true;
            if (border.l.y >= diagonal.r.y) return true;
            if (border.r.x <= diagonal.l.x) return true;
            if (border.r.y <= diagonal.l.y) return true;
            return false;
        }
    };

    alloc: std.mem.Allocator,
    simple: bool,
    corners: std.ArrayList(Point),
    borders: std.ArrayList(Line),

    pub fn init(alloc: std.mem.Allocator, simple: bool) Module {
        return .{
            .alloc = alloc,
            .simple = simple,
            .corners = std.ArrayList(Point).empty,
            .borders = std.ArrayList(Line).empty,
        };
    }

    pub fn deinit(self: *Module) void {
        self.borders.deinit(self.alloc);
        self.corners.deinit(self.alloc);
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ',');
        const point = Point.init(
            try std.fmt.parseInt(isize, it.next().?, 10),
            try std.fmt.parseInt(isize, it.next().?, 10),
        );
        try self.corners.append(self.alloc, point);
    }

    pub fn getLargestRectangle(self: *Module) !usize {
        std.debug.assert(self.corners.items.len > 1);

        if (!self.simple) {
            self.borders.clearRetainingCapacity();
            for (0..self.corners.items.len) |nl| {
                const nr = (nl + 1) % self.corners.items.len;
                const cl = self.corners.items[nl];
                const cr = self.corners.items[nr];
                const border = Line.initContaining(cl, cr);
                try self.borders.append(self.alloc, border);
            }
        }

        var top: usize = 0;
        for (0..self.corners.items.len) |nl| {
            const cl = self.corners.items[nl];
            for (nl + 1..self.corners.items.len) |nr| {
                const cr = self.corners.items[nr];

                const diagonal = Line.initContaining(cl, cr);
                const area = diagonal.areaSurroundedAsDiagonal();
                if (top >= area) continue;

                if (self.simple) {
                    top = area;
                    continue;
                }

                var valid = true;
                for (self.borders.items) |border| {
                    if (!border.outsideDiagonal(diagonal)) {
                        valid = false;
                        break;
                    }
                }
                if (valid) {
                    top = area;
                    continue;
                }
            }
        }
        return top;
    }
};

test "sample part 1" {
    const data =
        \\7,1
        \\11,1
        \\11,7
        \\9,7
        \\9,5
        \\2,5
        \\2,3
        \\7,3
    ;

    var module = Module.init(testing.allocator, true);
    defer module.deinit();

    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const product = try module.getLargestRectangle();
    const expected = @as(usize, 50);
    try testing.expectEqual(expected, product);
}

test "sample part 2" {
    const data =
        \\7,1
        \\11,1
        \\11,7
        \\9,7
        \\9,5
        \\2,5
        \\2,3
        \\7,3
    ;

    var module = Module.init(testing.allocator, false);
    defer module.deinit();

    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const product = try module.getLargestRectangle();
    const expected = @as(usize, 24);
    try testing.expectEqual(expected, product);
}
