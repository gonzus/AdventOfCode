const std = @import("std");
const testing = std.testing;

pub const Paper = struct {
    const Present = struct {
        l: usize,
        w: usize,
        h: usize,

        pub fn requiredPaper(self: Present) usize {
            var smallest: usize = std.math.maxInt(usize);
            const s1 = self.l * self.w;
            if (smallest > s1) smallest = s1;
            const s2 = self.l * self.h;
            if (smallest > s2) smallest = s2;
            const s3 = self.w * self.h;
            if (smallest > s3) smallest = s3;
            const total = 2 * (s1 + s2 + s3) + smallest;
            return total;
        }

        pub fn requiredRibbon(self: Present) usize {
            var smallest: usize = std.math.maxInt(usize);
            const p1 = self.l + self.w;
            if (smallest > p1) smallest = p1;
            const p2 = self.l + self.h;
            if (smallest > p2) smallest = p2;
            const p3 = self.w + self.h;
            if (smallest > p3) smallest = p3;
            const total = 2 * smallest + self.l * self.w * self.h;
            return total;
        }
    };

    total_paper: usize,
    total_ribbon: usize,

    pub fn init() Paper {
        const self = Paper{
            .total_paper = 0,
            .total_ribbon = 0,
        };
        return self;
    }

    pub fn addLine(self: *Paper, line: []const u8) !void {
        var pos: usize = 0;
        var present: Present = undefined;
        var it = std.mem.tokenizeScalar(u8, line, 'x');
        while (it.next()) |chunk| : (pos += 1) {
            const n = try std.fmt.parseUnsigned(usize, chunk, 10);
            switch (pos) {
                0 => present.l = n,
                1 => present.w = n,
                2 => present.h = n,
                else => return error.InvalidData,
            }
        }
        self.total_paper += present.requiredPaper();
        self.total_ribbon += present.requiredRibbon();
    }

    pub fn getTotalPaperNeeded(self: Paper) usize {
        return self.total_paper;
    }

    pub fn getTotalRibbonNeeded(self: Paper) usize {
        return self.total_ribbon;
    }
};

test "sample part 1" {
    const data =
        \\2x3x4
        \\1x1x10
    ;

    var paper = Paper.init();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try paper.addLine(line);
    }

    const count = paper.getTotalPaperNeeded();
    const expected = @as(usize, 58 + 43);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\2x3x4
        \\1x1x10
    ;

    var paper = Paper.init();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try paper.addLine(line);
    }

    const count = paper.getTotalRibbonNeeded();
    const expected = @as(usize, 34 + 14);
    try testing.expectEqual(expected, count);
}
