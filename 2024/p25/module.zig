const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const ROWS = 7;
    const COLS = 5;

    const Kind = enum { lock, key, unknown };
    const Numbers = [COLS]u8;

    locks: std.ArrayList(Numbers),
    keys: std.ArrayList(Numbers),
    kind: Kind,
    current: Numbers,
    height: usize,

    pub fn init(allocator: Allocator) Module {
        var self = Module{
            .locks = std.ArrayList(Numbers).init(allocator),
            .keys = std.ArrayList(Numbers).init(allocator),
            .kind = undefined,
            .current = undefined,
            .height = undefined,
        };
        self.resetCurrent();
        return self;
    }

    pub fn deinit(self: *Module) void {
        self.keys.deinit();
        self.locks.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        if (line.len == 0) return;

        var full = true;
        for (0..line.len) |p| {
            const c = line[p];
            if (c == '#') {
                self.current[p] += 1;
            } else {
                full = false;
            }
        }
        self.height += 1;

        if (full) {
            if (self.height == 1) {
                if (self.kind != .unknown) return error.InconsistentKind;
                self.kind = .lock;
            }
            if (self.height == ROWS) {
                if (self.kind != .unknown) return error.InconsistentKind;
                self.kind = .key;
            }
        }
        if (self.height < ROWS) return;

        for (0..COLS) |p| {
            self.current[p] -= 1;
        }
        switch (self.kind) {
            .lock => try self.locks.append(self.current),
            .key => try self.keys.append(self.current),
            .unknown => return error.InvalidKind,
        }
        self.resetCurrent();
    }

    // pub fn show(self: Module) void {
    //     std.debug.print("Locks: {}\n", .{self.locks.items.len});
    //     for (self.locks.items) |lock| {
    //         std.debug.print(" {d}\n", .{lock});
    //     }
    //
    //     std.debug.print("Keys: {}\n", .{self.keys.items.len});
    //     for (self.keys.items) |key| {
    //         std.debug.print(" {d}\n", .{key});
    //     }
    // }

    pub fn countMatchingLocksAndKeys(self: *Module) !u64 {
        // self.show();
        var count: usize = 0;
        for (self.locks.items) |lock| {
            for (self.keys.items) |key| {
                var match = true;
                for (0..COLS) |p| {
                    if (lock[p] + key[p] < ROWS - 1) continue;
                    match = false;
                    break;
                }
                if (!match) continue;
                count += 1;
            }
        }
        return count;
    }

    fn resetCurrent(self: *Module) void {
        self.kind = .unknown;
        self.height = 0;
        self.current = [_]u8{0} ** COLS;
    }
};

test "sample part 1" {
    const data =
        \\#####
        \\.####
        \\.####
        \\.####
        \\.#.#.
        \\.#...
        \\.....
        \\
        \\#####
        \\##.##
        \\.#.##
        \\...##
        \\...#.
        \\...#.
        \\.....
        \\
        \\.....
        \\#....
        \\#....
        \\#...#
        \\#.#.#
        \\#.###
        \\#####
        \\
        \\.....
        \\.....
        \\#.#..
        \\###..
        \\###.#
        \\###.#
        \\#####
        \\
        \\.....
        \\.....
        \\.....
        \\#....
        \\#.#..
        \\#.#.#
        \\#####
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const sum = try module.countMatchingLocksAndKeys();
    const expected = @as(u64, 3);
    try testing.expectEqual(expected, sum);
}
