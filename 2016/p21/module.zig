const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Scrambler = struct {
    const Op = union(enum) {
        swap_pos: struct { x: usize, y: usize },
        swap_char: struct { x: u8, y: u8 },
        rotate_left: struct { x: usize },
        rotate_right: struct { x: usize },
        rotate_char: struct { x: u8 },
        reverse: struct { x: usize, y: usize },
        move: struct { x: usize, y: usize },

        pub fn apply(self: Op, buf: []u8) void {
            switch (self) {
                .swap_pos => |o| string_swap(buf, o.x, o.y),
                .swap_char => |o| {
                    const px = std.mem.indexOfScalar(u8, buf, o.x).?;
                    const py = std.mem.indexOfScalar(u8, buf, o.y).?;
                    string_swap(buf, px, py);
                },
                .rotate_left => |o| string_rotate(buf, o.x, true),
                .rotate_right => |o| string_rotate(buf, o.x, false),
                .rotate_char => |o| {
                    const px = std.mem.indexOfScalar(u8, buf, o.x).?;
                    var rot: usize = 1 + px;
                    if (px >= 4) rot += 1;
                    string_rotate(buf, rot, false);
                },
                .reverse => |o| string_reverse(buf, o.x, o.y),
                .move => |o| string_move(buf, o.x, o.y),
            }
        }

        pub fn revert(self: Op, buf: []u8) void {
            switch (self) {
                .swap_pos => |o| string_swap(buf, o.x, o.y),
                .swap_char => |o| {
                    const px = std.mem.indexOfScalar(u8, buf, o.x).?;
                    const py = std.mem.indexOfScalar(u8, buf, o.y).?;
                    string_swap(buf, px, py);
                },
                .rotate_left => |o| string_rotate(buf, o.x, false),
                .rotate_right => |o| string_rotate(buf, o.x, true),
                .rotate_char => |o| {
                    const px = std.mem.indexOfScalar(u8, buf, o.x).?;
                    var rot: usize = px / 2 + 1;
                    if (px > 0 and px % 2 == 0) rot += 4;
                    string_rotate(buf, rot, true);
                },
                .reverse => |o| string_reverse(buf, o.x, o.y),
                .move => |o| string_move(buf, o.y, o.x),
            }
        }

        fn string_swap(str: []u8, l: usize, r: usize) void {
            if (l == r) return;
            const t = str[l];
            str[l] = str[r];
            str[r] = t;
        }

        fn string_rotate(str: []u8, delta: usize, left: bool) void {
            var tmp: [100]u8 = undefined;
            for (str, 0..) |_, p| {
                var q = p;
                q += str.len;
                if (left) {
                    q -= delta;
                } else {
                    q += delta;
                }
                q %= str.len;
                tmp[q] = str[p];
            }
            std.mem.copyForwards(u8, str, tmp[0..str.len]);
        }

        fn string_move(str: []u8, src: usize, tgt: usize) void {
            var tmp: [100]u8 = undefined;
            var q: usize = 0;
            const l = str[src];
            for (str, 0..) |c, p| {
                if (p == src) {
                    continue;
                }
                if (q == tgt) {
                    tmp[q] = l;
                    q += 1;
                }
                tmp[q] = c;
                q += 1;
            }
            if (q < str.len) {
                tmp[q] = l;
                q += 1;
            }
            std.mem.copyForwards(u8, str, tmp[0..str.len]);
        }

        fn string_reverse(str: []u8, beg: usize, end: usize) void {
            if (beg >= end) return;
            const mid: usize = (end - beg + 1) / 2;
            for (0..mid) |p| {
                const t = str[beg + p];
                str[beg + p] = str[end - p];
                str[end - p] = t;
            }
        }
    };

    ops: std.ArrayList(Op),
    buf: [100]u8,

    pub fn init(allocator: Allocator) Scrambler {
        return .{
            .ops = std.ArrayList(Op).init(allocator),
            .buf = undefined,
        };
    }

    pub fn deinit(self: *Scrambler) void {
        self.ops.deinit();
    }

    pub fn addLine(self: *Scrambler, line: []const u8) !void {
        try self.ops.append(try buildOp(line));
    }

    pub fn show(self: Scrambler) void {
        std.debug.print("Scrambler with {} operations:\n", .{self.ops.items.len});
        for (self.ops.items) |o| {
            std.debug.print("{}\n", .{o});
        }
    }

    pub fn getScrambledPassword(self: *Scrambler, password: []const u8) ![]const u8 {
        std.mem.copyForwards(u8, &self.buf, password);
        for (self.ops.items) |o| {
            o.apply(self.buf[0..password.len]);
        }
        return self.buf[0..password.len];
    }

    pub fn getUnscrambledPassword(self: *Scrambler, password: []const u8) ![]const u8 {
        std.mem.copyForwards(u8, &self.buf, password);
        for (self.ops.items, 0..) |_, n| {
            const o = self.ops.items[self.ops.items.len - n - 1];
            o.revert(self.buf[0..password.len]);
        }
        return self.buf[0..password.len];
    }

    fn buildOp(line: []const u8) !Op {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        const verb = it.next().?;
        if (std.mem.eql(u8, verb, "swap")) {
            const what = it.next().?;
            if (std.mem.eql(u8, what, "position")) {
                const x = try std.fmt.parseUnsigned(usize, it.next().?, 10);
                _ = it.next();
                _ = it.next();
                const y = try std.fmt.parseUnsigned(usize, it.next().?, 10);
                return Op{ .swap_pos = .{ .x = x, .y = y } };
            }
            if (std.mem.eql(u8, what, "letter")) {
                const x = it.next().?[0];
                _ = it.next();
                _ = it.next();
                const y = it.next().?[0];
                return Op{ .swap_char = .{ .x = x, .y = y } };
            }
            return error.InvalidOp;
        }
        if (std.mem.eql(u8, verb, "rotate")) {
            const what = it.next().?;
            if (std.mem.eql(u8, what, "left")) {
                const x = try std.fmt.parseUnsigned(usize, it.next().?, 10);
                return Op{ .rotate_left = .{ .x = x } };
            }
            if (std.mem.eql(u8, what, "right")) {
                const x = try std.fmt.parseUnsigned(usize, it.next().?, 10);
                return Op{ .rotate_right = .{ .x = x } };
            }
            if (std.mem.eql(u8, what, "based")) {
                _ = it.next();
                _ = it.next();
                _ = it.next();
                _ = it.next();
                const x = it.next().?[0];
                return Op{ .rotate_char = .{ .x = x } };
            }
            return error.InvalidOp;
        }
        if (std.mem.eql(u8, verb, "reverse")) {
            _ = it.next();
            const x = try std.fmt.parseUnsigned(usize, it.next().?, 10);
            _ = it.next();
            const y = try std.fmt.parseUnsigned(usize, it.next().?, 10);
            return Op{ .reverse = .{ .x = x, .y = y } };
        }
        if (std.mem.eql(u8, verb, "move")) {
            _ = it.next();
            const x = try std.fmt.parseUnsigned(usize, it.next().?, 10);
            _ = it.next();
            _ = it.next();
            const y = try std.fmt.parseUnsigned(usize, it.next().?, 10);
            return Op{ .move = .{ .x = x, .y = y } };
        }
        return error.InvalidOp;
    }
};

test "sample part 1" {
    const data =
        \\swap position 4 with position 0
        \\swap letter d with letter b
        \\reverse positions 0 through 4
        \\rotate left 1 step
        \\move position 1 to position 4
        \\move position 3 to position 0
        \\rotate based on position of letter b
        \\rotate based on position of letter d
    ;

    var scrambler = Scrambler.init(std.testing.allocator);
    defer scrambler.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try scrambler.addLine(line);
    }
    // scrambler.show();

    const password = try scrambler.getScrambledPassword("abcde");
    const expected = "decab";
    try testing.expectEqualStrings(expected, password);
}

test "sample part 2" {
    const data =
        \\swap position 4 with position 0
        \\swap letter d with letter b
        \\reverse positions 0 through 4
        \\rotate left 1 step
        \\move position 1 to position 4
        \\move position 3 to position 0
        \\rotate based on position of letter b
        \\rotate based on position of letter d
    ;

    var scrambler = Scrambler.init(std.testing.allocator);
    defer scrambler.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try scrambler.addLine(line);
    }
    // scrambler.show();

    const password = try scrambler.getUnscrambledPassword("decab");
    const expected = "abcde";
    try testing.expectEqualStrings(expected, password);
}
