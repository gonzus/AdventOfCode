const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;
const DEQueue = @import("./util/queue.zig").DoubleEndedQueue;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const StringId = StringTable.StringId;
    const INFINITY = std.math.maxInt(usize);

    const Pos = struct {
        x: usize,
        y: usize,

        pub fn init(x: usize, y: usize) Pos {
            return .{ .x = x, .y = y };
        }

        pub fn equals(self: Pos, other: Pos) bool {
            return self.x == other.x and self.y == other.y;
        }

        pub fn format(
            pos: Pos,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("({}:{})", .{ pos.x, pos.y });
        }
    };

    const Delta = struct {
        x: isize,
        y: isize,

        pub fn init(x: isize, y: isize) Delta {
            return .{ .x = x, .y = y };
        }

        pub fn format(
            delta: Delta,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("[{}:{}]", .{ delta.x, delta.y });
        }
    };

    const Dir = enum(u8) {
        U = '^',
        D = 'v',
        L = '<',
        R = '>',

        pub fn delta(self: Dir) Delta {
            return switch (self) {
                .U => Delta.init(0, -1),
                .D => Delta.init(0, 1),
                .L => Delta.init(-1, 0),
                .R => Delta.init(1, 0),
            };
        }
    };
    const Dirs = std.meta.tags(Dir);

    const Pad = struct {
        keys: std.AutoHashMap(u8, Pos),

        pub fn init(allocator: Allocator) Pad {
            return .{
                .keys = std.AutoHashMap(u8, Pos).init(allocator),
            };
        }

        pub fn deinit(self: *Pad) void {
            self.keys.deinit();
        }

        pub fn parse(self: *Pad, keys: []const u8, width: usize) !void {
            for (0..keys.len) |p| {
                const x: usize = p % width;
                const y: usize = p / width;
                try self.keys.put(keys[p], Pos.init(x, y));
            }
        }

        pub fn get(self: Pad, key: u8) Pos {
            return self.keys.get(key).?;
        }

        pub fn invalid(self: Pad) Pos {
            return self.get('.');
        }
    };

    const RobotState = struct {
        path: StringId,
        count: usize,

        pub fn init(path: StringId, count: usize) RobotState {
            return .{ .path = path, .count = count };
        }
    };

    const DirState = struct {
        path: StringId,
        pos: Pos,

        pub fn init(path: StringId, pos: Pos) DirState {
            return .{ .path = path, .pos = pos };
        }
    };
    const DirQueue = DEQueue(DirState);

    allocator: Allocator,
    strtab: StringTable,
    num_pad: Pad,
    dir_pad: Pad,
    codes: std.ArrayList(StringId),
    robot_cache: std.AutoHashMap(RobotState, usize),

    pub fn init(allocator: Allocator) Module {
        var self = Module{
            .allocator = allocator,
            .strtab = StringTable.init(allocator),
            .num_pad = Pad.init(allocator),
            .dir_pad = Pad.init(allocator),
            .codes = std.ArrayList(StringId).init(allocator),
            .robot_cache = std.AutoHashMap(RobotState, usize).init(allocator),
        };
        self.num_pad.parse("789456123.0A", 3) catch {
            @panic("WTF");
        };
        self.dir_pad.parse(".^A<v>", 3) catch {
            @panic("WTF");
        };
        return self;
    }

    pub fn deinit(self: *Module) void {
        self.robot_cache.deinit();
        self.codes.deinit();
        self.dir_pad.deinit();
        self.num_pad.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        const code = try self.strtab.add(line);
        try self.codes.append(code);
    }

    pub fn getSumComplexities(self: *Module, count: usize) !usize {
        var value: usize = 0;
        for (self.codes.items) |c| {
            const code = self.strtab.get_str(c) orelse "***";
            var number: usize = 0;
            var result: usize = 0;
            var cpos = self.num_pad.get('A');
            for (code) |val| {
                if (val >= '0' and val <= '9') {
                    number *= 10;
                    number += val - '0';
                }
                const npos = self.num_pad.get(val);
                const best = try self.bestDir(cpos, npos, count, 0, &self.num_pad);
                result += best;
                cpos = npos;
            }
            value += result * number;
        }
        return value;
    }

    fn getsCloser(old: usize, new: usize, delta: isize) bool {
        if (delta < 0) return new < old;
        if (delta > 0) return new > old;
        return false;
    }

    const WalkErrors = error{ OutOfMemory, QueueEmpty };

    fn walkBestPath(self: *Module, path: []const u8, count: usize) WalkErrors!usize {
        if (count == 1) return path.len;

        const p = try self.strtab.add(path);
        const state = RobotState.init(p, count);
        if (self.robot_cache.get(state)) |best| {
            return best;
        }

        var best: usize = 0;
        var cpos = self.dir_pad.get('A');
        for (path) |d| {
            const npos = self.dir_pad.get(d);
            best += try self.bestDir(cpos, npos, count, 1, &self.dir_pad);
            cpos = npos;
        }
        try self.robot_cache.put(state, best);
        return best;
    }

    fn bestDir(self: *Module, opos: Pos, npos: Pos, count: usize, consume: usize, pad: *Pad) WalkErrors!usize {
        var best: usize = INFINITY;
        var todo = DirQueue.init(self.allocator);
        defer todo.deinit();
        const epath = try self.strtab.add("");
        try todo.append(DirState.init(epath, opos));
        while (!todo.empty()) {
            const s = try todo.pop();
            const path = self.strtab.get_str(s.path) orelse "***";
            var buf: [1024]u8 = undefined;
            std.mem.copyForwards(u8, &buf, path);

            if (s.pos.equals(npos)) {
                buf[path.len] = 'A';
                const b = try self.walkBestPath(buf[0 .. path.len + 1], count - consume);
                if (best > b) best = b;
                continue;
            }

            if (s.pos.equals(pad.invalid())) continue;

            for (Dirs) |dir| {
                const delta = dir.delta();
                var valid = false;
                valid = valid or getsCloser(s.pos.x, npos.x, delta.x);
                valid = valid or getsCloser(s.pos.y, npos.y, delta.y);
                if (!valid) continue;

                var ix: isize = @intCast(s.pos.x);
                var iy: isize = @intCast(s.pos.y);
                ix += delta.x;
                iy += delta.y;
                const pos = Pos.init(@intCast(ix), @intCast(iy));
                buf[path.len] = @intFromEnum(dir);
                const npath = try self.strtab.add(buf[0 .. path.len + 1]);
                try todo.append(DirState.init(npath, pos));
            }
        }
        return best;
    }
};

test "sample part 1" {
    const data =
        \\029A
        \\980A
        \\179A
        \\456A
        \\379A
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const sum = try module.getSumComplexities(3);
    const expected = @as(usize, 126384);
    try testing.expectEqual(expected, sum);
}
