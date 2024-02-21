const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Promenade = struct {
    const StringId = usize;
    const SIZE = 16;

    const Move = union(enum) {
        spin: usize,
        exchange: struct {
            p0: usize,
            p1: usize,
        },
        partner: struct {
            c0: u8,
            c1: u8,
        },

        pub fn parse(str: []const u8) !Move {
            const c = str[0];
            const rest = str[1..];
            switch (c) {
                's' => {
                    const num = try std.fmt.parseUnsigned(usize, rest, 10);
                    return Move{ .spin = num };
                },
                'x' => {
                    var it = std.mem.tokenizeScalar(u8, rest, '/');
                    const p0 = try std.fmt.parseUnsigned(usize, it.next().?, 10);
                    const p1 = try std.fmt.parseUnsigned(usize, it.next().?, 10);
                    return Move{ .exchange = .{ .p0 = p0, .p1 = p1 } };
                },
                'p' => {
                    var it = std.mem.tokenizeScalar(u8, rest, '/');
                    const c0 = it.next().?[0];
                    const c1 = it.next().?[0];
                    return Move{ .partner = .{ .c0 = c0, .c1 = c1 } };
                },
                else => return error.InvalidMove,
            }
        }

        pub fn apply(self: Move, line: []u8) void {
            switch (self) {
                .spin => |m| {
                    var buf: [SIZE]u8 = undefined;
                    std.mem.copyForwards(u8, &buf, line);
                    const copy = buf[0..line.len];
                    std.mem.copyForwards(u8, line[0..m], copy[line.len - m ..]);
                    std.mem.copyForwards(u8, line[m..line.len], copy[0 .. line.len - m]);
                },
                .exchange => |m| {
                    std.mem.swap(u8, &line[m.p0], &line[m.p1]);
                },
                .partner => |m| {
                    var p0: usize = undefined;
                    var p1: usize = undefined;
                    for (line, 0..) |c, p| {
                        if (c == m.c0) p0 = p;
                        if (c == m.c1) p1 = p;
                    }
                    std.mem.swap(u8, &line[p0], &line[p1]);
                },
            }
        }
    };

    size: usize,
    line: [SIZE]u8,
    moves: std.ArrayList(Move),
    strtab: StringTable,
    seen: std.AutoHashMap(StringId, usize),

    pub fn init(allocator: Allocator, size: usize) Promenade {
        var self = Promenade{
            .size = if (size == 0) SIZE else size,
            .line = undefined,
            .strtab = StringTable.init(allocator),
            .moves = std.ArrayList(Move).init(allocator),
            .seen = std.AutoHashMap(StringId, usize).init(allocator),
        };
        for (0..self.size) |p| {
            self.line[p] = @intCast(p);
            self.line[p] += 'a';
        }
        return self;
    }

    pub fn deinit(self: *Promenade) void {
        self.seen.deinit();
        self.moves.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Promenade, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ',');
        while (it.next()) |chunk| {
            try self.moves.append(try Move.parse(chunk));
        }
    }

    pub fn runMovesTimes(self: *Promenade, times: usize) ![]const u8 {
        var found = false;
        var current: usize = 0;
        const state = self.line[0..self.size];
        while (current < times) {
            self.dance();
            current += 1;
            if (found) continue;

            const id = try self.strtab.add(state);
            const r = try self.seen.getOrPut(id);
            if (!r.found_existing) {
                r.value_ptr.* = current;
                continue;
            }

            found = true;
            const start = r.value_ptr.*;
            const length = current - start;
            const left = (times - current) % length;
            current = times - left;
        }
        return state;
    }

    fn dance(self: *Promenade) void {
        for (self.moves.items) |m| {
            m.apply(self.line[0..self.size]);
        }
    }
};

test "sample part 1" {
    const data =
        \\s1,x3/4,pe/b
    ;

    var promenade = Promenade.init(testing.allocator, 5);
    defer promenade.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try promenade.addLine(line);
    }

    const order = try promenade.runMovesTimes(1);
    const expected = "baedc";
    try testing.expectEqualSlices(u8, expected, order);
}
