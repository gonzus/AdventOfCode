const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Document = struct {
    const Triangle = struct {
        pos: usize,
        sides: [3]usize,

        pub fn init() Triangle {
            return Triangle{
                .pos = 0,
                .sides = [_]usize{0} ** 3,
            };
        }

        pub fn addSide(self: *Triangle, side: usize) !void {
            if (self.pos >= 3) return error.InvalidTriangle;
            self.sides[self.pos] = side;
            self.pos += 1;
        }

        pub fn isValid(self: Triangle) bool {
            if (self.pos != 3) return false;
            if (self.sides[0] + self.sides[1] <= self.sides[2]) return false;
            if (self.sides[1] + self.sides[2] <= self.sides[0]) return false;
            if (self.sides[2] + self.sides[0] <= self.sides[1]) return false;
            return true;
        }
    };

    vertical: bool,
    triangles: std.ArrayList(Triangle),

    pub fn init(allocator: Allocator, vertical: bool) !Document {
        return Document{
            .vertical = vertical,
            .triangles = std.ArrayList(Triangle).init(allocator),
        };
    }

    pub fn deinit(self: *Document) void {
        self.triangles.deinit();
    }

    pub fn addLine(self: *Document, line: []const u8) !void {
        var triangle = Triangle.init();
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        while (it.next()) |chunk| {
            try triangle.addSide(try std.fmt.parseUnsigned(usize, chunk, 10));
        }
        try self.triangles.append(triangle);
        try self.checkAndConvert();
    }

    pub fn getValidTriangles(self: *Document) usize {
        var count: usize = 0;
        for (self.triangles.items) |triangle| {
            if (!triangle.isValid()) continue;
            count += 1;
        }
        return count;
    }

    fn checkAndConvert(self: *Document) !void {
        if (!self.vertical) return;

        const len = self.triangles.items.len;
        if (len % 3 != 0) return;

        var new: [3]Triangle = undefined;
        for (0..3) |n| {
            new[n] = Triangle.init();
            for (0..3) |o| {
                try new[n].addSide(self.triangles.items[len - o - 1].sides[n]);
            }
        }
        for (0..3) |n| {
            self.triangles.items[len - n - 1] = new[n];
        }
    }
};

test "sample part 1" {
    const data =
        \\5 10 25
    ;

    var document = try Document.init(std.testing.allocator, false);
    defer document.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try document.addLine(line);
    }

    const count = document.getValidTriangles();
    const expected = @as(usize, 0);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\5 5 5
        \\10 4 12
        \\25 3 13
    ;

    var document = try Document.init(std.testing.allocator, true);
    defer document.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try document.addLine(line);
    }

    const count = document.getValidTriangles();
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, count);
}
