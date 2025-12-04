const std = @import("std");
const testing = std.testing;

pub const Module = struct {
    const deltas = [_]isize{ -1, 0, 1 };

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            return .{ .x = x, .y = y };
        }

        // gnarly, but at least we isolate it
        pub fn move(self: Pos, dx: isize, dy: isize, w: usize, h: usize) ?Pos {
            if (dx == 0 and dy == 0) return null;
            if (dy == -1 and self.y <= 0) return null;
            if (dy == 1 and self.y >= h - 1) return null;
            if (dx == -1 and self.x <= 0) return null;
            if (dx == 1 and self.x >= w - 1) return null;
            return Pos.init(
                @intCast(@as(isize, @intCast(self.x)) + dx),
                @intCast(@as(isize, @intCast(self.y)) + dy),
            );
        }
    };

    alloc: std.mem.Allocator,
    current: usize,
    w: usize,
    h: usize,
    rolls: [2]std.AutoHashMap(Pos, void),

    pub fn init(alloc: std.mem.Allocator) Module {
        var self = Module{
            .alloc = alloc,
            .current = 0,
            .w = 0,
            .h = 0,
            .rolls = undefined,
        };
        for (0..2) |p| {
            self.rolls[p] = std.AutoHashMap(Pos, void).init(alloc);
        }
        return self;
    }

    pub fn deinit(self: *Module) void {
        for (0..2) |p| {
            self.rolls[p].deinit();
        }
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        if (self.w == 0) self.w = line.len;
        if (self.w != line.len) return error.InvalidData;
        const y = self.h;
        for (0..line.len) |x| {
            if (line[x] != '@') continue;
            try self.rolls[self.current].put(Pos.init(x, y), {});
        }
        self.h += 1;
    }

    pub fn countAccessibleRolls(self: *Module) !usize {
        var count: usize = 0;
        var it = self.rolls[self.current].keyIterator();
        ADJ: while (it.next()) |pos| {
            var adj: usize = 0;
            for (deltas) |dy| {
                for (deltas) |dx| {
                    if (pos.move(dx, dy, self.w, self.h)) |new| {
                        if (self.rolls[self.current].get(new)) |_| {
                            adj += 1;
                            if (adj >= 4) continue :ADJ;
                        }
                    }
                }
            }
            count += 1;
        }
        return count;
    }

    pub fn removeAccessibleRolls(self: *Module) !usize {
        var removed: usize = 0;
        while (true) {
            var changed: usize = 0;
            const next = 1 - self.current;
            self.rolls[next].clearRetainingCapacity();
            var it = self.rolls[self.current].keyIterator();
            ADJ: while (it.next()) |pos| {
                var adj: usize = 0;
                for (deltas) |dy| {
                    for (deltas) |dx| {
                        if (pos.move(dx, dy, self.w, self.h)) |new| {
                            if (self.rolls[self.current].get(new)) |_| {
                                adj += 1;
                                if (adj >= 4) {
                                    try self.rolls[next].put(pos.*, {});
                                    continue :ADJ;
                                }
                            }
                        }
                    }
                }
                changed += 1;
            }
            self.current = next;
            if (changed == 0) break;
            removed += changed;
        }
        return removed;
    }
};

test "sample part 1" {
    const data =
        \\..@@.@@@@.
        \\@@@.@.@.@@
        \\@@@@@.@.@@
        \\@.@@@@..@.
        \\@@.@@@@.@@
        \\.@@@@@@@.@
        \\.@.@.@.@@@
        \\@.@@@.@@@@
        \\.@@@@@@@@.
        \\@.@.@@@.@.
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const rolls = try module.countAccessibleRolls();
    const expected = @as(usize, 13);
    try testing.expectEqual(expected, rolls);
}

test "sample part 2" {
    const data =
        \\..@@.@@@@.
        \\@@@.@.@.@@
        \\@@@@@.@.@@
        \\@.@@@@..@.
        \\@@.@@@@.@@
        \\.@@@@@@@.@
        \\.@.@.@.@@@
        \\@.@@@.@@@@
        \\.@@@@@@@@.
        \\@.@.@@@.@.
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.splitScalar(u8, data, '\n');
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const removed = try module.removeAccessibleRolls();
    const expected = @as(usize, 43);
    try testing.expectEqual(expected, removed);
}
