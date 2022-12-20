const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Map = struct {
    allocator: Allocator,
    orig: std.ArrayList(isize),

    pub fn init(allocator: Allocator) Map {
        var self = Map{
            .allocator = allocator,
            .orig = std.ArrayList(isize).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Map) void {
        self.orig.deinit();
    }

    pub fn add_line(self: *Map, line: []const u8) !void {
        const num = try std.fmt.parseInt(isize, line, 10);
        try self.orig.append(num);
    }

    pub fn show(self: Map) void {
        std.debug.print("-- Map --------\n", .{});
        std.debug.print("  Orig:", .{});
        for (self.orig.items) |orig| {
            std.debug.print(" {}", .{orig});
        }
        std.debug.print("\n", .{});
    }

    fn sign(num: isize) isize {
        if (num > 0) return 1;
        if (num < 0) return -1;
        return 0;
    }

    fn add_wrap(num: isize, delta: isize) usize {
        return @intCast(usize, @rem(@rem(num, delta) + delta, delta));
    }

    pub fn mix_data(self: *Map, key: isize, rounds: usize) !isize {
        // copy of original values
        var work = std.ArrayList(isize).init(self.allocator);
        defer work.deinit();

        // mapping from pos to index
        var pos2idx = std.ArrayList(isize).init(self.allocator);
        defer pos2idx.deinit();

        // mapping from index tp pos
        var idx2pos = std.ArrayList(isize).init(self.allocator);
        defer idx2pos.deinit();

        var zero_orig: usize = undefined;
        for (self.orig.items) |num, pos| {
            if (num == 0) zero_orig = pos; // remember location of 0;
            try work.append(num * key); // copy all original values;

            // populate maps
            const p = @intCast(isize, pos);
            try pos2idx.append(p);
            try idx2pos.append(p);
        }

        const size = @intCast(isize, work.items.len);
        var round: usize = 0;
        while (round < rounds) : (round += 1) {
            std.debug.print("ROUND {}\n", .{round+1});
            for (work.items) |num, pos| {
                var src_idx = pos2idx.items[pos];
                var tgt_idx = src_idx + @rem(num, size - 1); // LOL
                const d = sign(num);
                var p: isize = src_idx;
                while (p != tgt_idx) : (p += d) {
                    // source and target indexes
                    var s_idx = add_wrap(p+0, size);
                    var t_idx = add_wrap(p+d, size);

                    // source and target positions
                    var s_pos = @intCast(usize, idx2pos.items[s_idx]);
                    var t_pos = @intCast(usize, idx2pos.items[t_idx]);

                    // swap everything
                    pos2idx.items[s_pos] = @intCast(isize, t_idx);
                    pos2idx.items[t_pos] = @intCast(isize, s_idx);
                    idx2pos.items[s_idx] = @intCast(isize, t_pos);
                    idx2pos.items[t_idx] = @intCast(isize, s_pos);
                }
            }
        }

        var sum: isize = 0;
        var c: isize = 1000;
        while (c <= 3000) : (c += 1000) {
            const zero_idx = add_wrap(pos2idx.items[zero_orig] + c, size);
            const zero_pos = @intCast(usize, idx2pos.items[zero_idx]);
            const coord = work.items[zero_pos];
            // std.debug.print("Coord at {} = {}\n", .{c, coord});
            sum += coord;
        }

        return sum;
    }
};

test "sample part 1" {
    std.debug.print("\n", .{});
    const data: []const u8 =
        \\1
        \\2
        \\-3
        \\3
        \\-2
        \\0
        \\4
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.add_line(line);
    }

    const sgc = try map.mix_data(1, 1);
    // map.show();

    try testing.expectEqual(@as(isize, 3), sgc);
}

test "sample part 2" {
    std.debug.print("\n", .{});
    const data: []const u8 =
        \\1
        \\2
        \\-3
        \\3
        \\-2
        \\0
        \\4
    ;

    var map = Map.init(std.testing.allocator);
    defer map.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try map.add_line(line);
    }

    const sgc = try map.mix_data(811589153, 10);
    // map.show();

    try testing.expectEqual(@as(isize, 1623178306), sgc);
}
