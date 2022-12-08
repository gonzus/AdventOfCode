const std = @import("std");
const testing = std.testing;

pub const Forest = struct {
    trees: [1024][1024]u8,
    width: usize,
    height: usize,

    pub fn init() Forest {
        var self = Forest{
            .trees = undefined,
            .width = 0,
            .height = 0,
        };
        return self;
    }

    pub fn deinit(self: *Forest) void {
        _ = self;
    }

    pub fn add_line(self: *Forest, line: []const u8) !void {
        if (self.width == 0) self.width = line.len;
        if (self.width != line.len) unreachable;
        for (line) |c, j| {
            self.trees[self.height][j] = c - '0';
        }
        self.height += 1;
    }

    pub fn show(self: Forest) void {
        var r: usize = 0;
        while (r < self.height) : (r += 1) {
            var c: usize = 0;
            while (c < self.width) : (c += 1) {
                std.debug.print("{}", .{self.trees[r][c]});
            }
            std.debug.print("\n", .{});
        }
    }

    fn can_be_seen_from_dir(self: Forest, r: usize, c: usize, dr: i32, dc: i32) bool {
        const height = self.trees[r][c];
        var tr: i32 = @intCast(i32, r);
        var tc: i32 = @intCast(i32, c);
        while (true) {
            tr += dr;
            if (tr < 0 or tr >= self.height) break;

            tc += dc;
            if (tc < 0 or tc >= self.width) break;

            const tree = self.trees[@intCast(usize, tr)][@intCast(usize, tc)];
            if (tree >= height) return false;
        }
        return true;
    }

    fn count_visible_trees_in_dir(self: Forest, r: usize, c: usize, dr: i32, dc: i32) usize {
        var count: usize = 0;
        const height = self.trees[r][c];
        var tr: i32 = @intCast(i32, r);
        var tc: i32 = @intCast(i32, c);
        while (true) {
            tr += dr;
            if (tr < 0 or tr >= self.height) break;

            tc += dc;
            if (tc < 0 or tc >= self.width) break;

            count += 1;
            const tree = self.trees[@intCast(usize, tr)][@intCast(usize, tc)];
            if (tree >= height) break;
        }
        return count;
    }

    pub fn count_visible(self: Forest) usize {
        var count: usize = self.width * 2 + self.height * 2 - 4;
        var r: usize = 1;
        while (r < self.height - 1) : (r += 1) {
            var c: usize = 1;
            while (c < self.width - 1) : (c += 1) {
                if (self.can_be_seen_from_dir(r, c, -1,  0) or
                    self.can_be_seen_from_dir(r, c,  1,  0) or
                    self.can_be_seen_from_dir(r, c, 0 , -1) or
                    self.can_be_seen_from_dir(r, c, 0 ,  1)) {
                    count += 1;
                }
            }
        }
        return count;
    }

    pub fn find_most_scenic(self: Forest) usize {
        var highest: usize = 0;
        var r: usize = 1;
        while (r < self.height - 1) : (r += 1) {
            var c: usize = 1;
            while (c < self.width - 1) : (c += 1) {
                const product = self.count_visible_trees_in_dir(r, c, -1,  0) *
                                self.count_visible_trees_in_dir(r, c,  1,  0) *
                                self.count_visible_trees_in_dir(r, c,  0, -1) *
                                self.count_visible_trees_in_dir(r, c,  0,  1);
                if (highest > product) continue;
                highest = product;
            }
        }
        return highest;
    }
};

test "sample part 1" {
    const data: []const u8 =
        \\30373
        \\25512
        \\65332
        \\33549
        \\35390
    ;

    var forest = Forest.init();
    defer forest.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try forest.add_line(line);
    }

    const count = forest.count_visible();
    try testing.expect(count == 21);
}

test "sample part 2" {
    const data: []const u8 =
        \\30373
        \\25512
        \\65332
        \\33549
        \\35390
    ;

    var forest = Forest.init();
    defer forest.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try forest.add_line(line);
    }

    const score = forest.find_most_scenic();
    try testing.expect(score == 8);
}
