const std = @import("std");
const testing = std.testing;
const Math = @import("./util/math.zig").Math;

const Allocator = std.mem.Allocator;

pub const Vault = struct {
    const INFINITY = std.math.maxInt(usize);
    const MAX_VAULT = 4;
    const MAX_PASSCODE = 20;
    const MAX_PATH = 1000;
    const Pos = Math.Vector(usize, 2);

    const Dir = enum {
        U,
        D,
        L,
        R,

        pub fn label(self: Dir) u8 {
            return @tagName(self)[0];
        }

        pub fn canMove(self: Dir, pos: Pos) bool {
            return switch (self) {
                .U => pos.v[1] > 0,
                .D => pos.v[1] < MAX_VAULT - 1,
                .L => pos.v[0] > 0,
                .R => pos.v[0] < MAX_VAULT - 1,
            };
        }
    };
    const Dirs = std.meta.tags(Dir);

    allocator: Allocator,
    longest: bool,
    best: usize,
    passcode_buf: [MAX_PASSCODE]u8,
    passcode_len: usize,
    path_buf: [MAX_PATH]u8,
    path_beg: usize,

    pub fn init(allocator: Allocator, longest: bool) Vault {
        return Vault{
            .allocator = allocator,
            .longest = longest,
            .best = 0,
            .passcode_buf = undefined,
            .passcode_len = 0,
            .path_buf = undefined,
            .path_beg = MAX_PATH,
        };
    }

    pub fn addLine(self: *Vault, line: []const u8) !void {
        std.mem.copyForwards(u8, &self.passcode_buf, line);
        self.passcode_len = line.len;
    }

    pub fn findShortestPath(self: *Vault) ![]const u8 {
        try self.walkFromBegToEnd();
        return self.path_buf[self.path_beg..MAX_PATH];
    }

    pub fn findLongestPathLength(self: *Vault) !usize {
        try self.walkFromBegToEnd();
        return self.best;
    }

    fn walkFromBegToEnd(self: *Vault) !void {
        const src = Pos.copy(&[_]usize{ 0, 0 });
        const tgt = Pos.copy(&[_]usize{ MAX_VAULT - 1, MAX_VAULT - 1 });
        try self.walkFromSrcToTgt(src, tgt);
    }

    const State = struct {
        pos: Pos,
        pbuf: [MAX_PATH]u8,
        plen: usize,

        pub fn init(pos: Pos) State {
            return .{ .pos = pos, .pbuf = undefined, .plen = 0 };
        }

        pub fn moveDir(self: State, dir: Dir) State {
            var next = State.init(self.pos);
            switch (dir) {
                .U => next.pos.v[1] -= 1,
                .D => next.pos.v[1] += 1,
                .L => next.pos.v[0] -= 1,
                .R => next.pos.v[0] += 1,
            }
            next.pbuf = self.pbuf;
            next.plen = self.plen;
            next.pbuf[next.plen] = dir.label();
            next.plen += 1;
            return next;
        }

        pub fn getDoors(self: State, passcode: []const u8) ![Dirs.len]bool {
            var buf: [MAX_PASSCODE + MAX_PATH]u8 = undefined;
            var len: usize = 0;
            std.mem.copyForwards(u8, buf[len..], passcode);
            len += passcode.len;
            const path = self.pbuf[0..self.plen];
            std.mem.copyForwards(u8, buf[len..], path);
            len += path.len;
            const str = buf[0..len];
            var hash: [std.crypto.hash.Md5.digest_length]u8 = undefined;
            std.crypto.hash.Md5.hash(str, &hash, .{});
            const U = (hash[0] >> 4) > 10;
            const D = (hash[0] & 0xf) > 10;
            const L = (hash[1] >> 4) > 10;
            const R = (hash[1] & 0xf) > 10;
            return [_]bool{ U, D, L, R };
        }
    };

    const StateDist = struct {
        state: State,
        dist: usize,

        pub fn init(state: State, dist: usize) StateDist {
            return .{ .state = state, .dist = dist };
        }

        fn lessThan(_: void, l: StateDist, r: StateDist) std.math.Order {
            const od = std.math.order(l.dist, r.dist);
            if (od != .eq) return od;

            const lp = l.state.pbuf[0..l.state.plen];
            const rp = r.state.pbuf[0..r.state.plen];
            return std.mem.order(u8, lp, rp);
        }
    };

    fn walkFromSrcToTgt(self: *Vault, src: Pos, tgt: Pos) !void {
        var path = std.AutoHashMap(State, State).init(self.allocator);
        defer path.deinit();
        var seen = std.AutoHashMap(State, void).init(self.allocator);
        defer seen.deinit();
        var distance = std.AutoHashMap(State, usize).init(self.allocator);
        defer distance.deinit();
        var pending = std.PriorityQueue(StateDist, void, StateDist.lessThan).init(self.allocator, {});
        defer pending.deinit();

        const src_state = State.init(src);
        try distance.put(src_state, 0);
        try pending.add(StateDist.init(src_state, 0));
        const passcode = self.passcode_buf[0..self.passcode_len];
        var final: ?State = null;
        while (pending.count() != 0) {
            const sdu = pending.remove();
            const u = sdu.state;
            if (u.pos.equal(tgt)) {
                if (self.longest) {
                    if (self.best < sdu.dist) self.best = sdu.dist;
                    continue;
                }
                final = u;
                break;
            }
            _ = try seen.put(u, {});

            const doors = try u.getDoors(passcode);
            for (Dirs, 0..) |dir, pos| {
                if (!doors[pos]) continue;

                if (!dir.canMove(u.pos)) continue;
                const v = u.moveDir(dir);

                if (seen.contains(v)) continue;

                var du: usize = INFINITY;
                if (distance.get(u)) |d| {
                    du = d;
                }
                var dv: usize = INFINITY;
                if (distance.get(v)) |d| {
                    dv = d;
                }
                const tentative = du + 1;
                if (tentative >= dv) continue;

                try path.put(v, u);
                try distance.put(v, tentative);
                try pending.add(StateDist.init(v, tentative));
            }
        }

        while (final) |f| {
            const parent = path.get(f);
            if (parent) |p| {
                self.path_beg -= 1;
                self.path_buf[self.path_beg] = try getMoveDir(p.pos, f.pos);
                final = p;
            } else return;
        }

        if (self.longest) {
            if (self.best > 0) return;
        }

        return error.PathNotFound;
    }

    fn getMoveDir(src: Pos, tgt: Pos) !u8 {
        if (tgt.v[0] == src.v[0]) {
            if (tgt.v[1] + 1 == src.v[1]) return Dir.U.label();
            if (tgt.v[1] == src.v[1] + 1) return Dir.D.label();
            return error.InvalidMove;
        }
        if (tgt.v[1] == src.v[1]) {
            if (tgt.v[0] + 1 == src.v[0]) return Dir.L.label();
            if (tgt.v[0] == src.v[0] + 1) return Dir.R.label();
            return error.InvalidMove;
        }
        return error.InvalidMove;
    }
};

test "sample part 1 case A" {
    const data =
        \\ihgpwlah
    ;

    var vault = Vault.init(testing.allocator, false);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try vault.addLine(line);
    }

    const path = try vault.findShortestPath();
    const expected = "DDRRRD";
    try testing.expectEqualSlices(u8, expected, path);
}

test "sample part 1 case B" {
    const data =
        \\kglvqrro
    ;

    var vault = Vault.init(testing.allocator, false);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try vault.addLine(line);
    }

    const path = try vault.findShortestPath();
    const expected = "DDUDRLRRUDRD";
    try testing.expectEqualSlices(u8, expected, path);
}

test "sample part 1 case C" {
    const data =
        \\ulqzkmiv
    ;

    var vault = Vault.init(testing.allocator, false);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try vault.addLine(line);
    }

    const path = try vault.findShortestPath();
    const expected = "DRURDRUDDLLDLUURRDULRLDUUDDDRR";
    try testing.expectEqualSlices(u8, expected, path);
}

test "sample part 2 case A" {
    const data =
        \\ihgpwlah
    ;

    var vault = Vault.init(testing.allocator, true);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try vault.addLine(line);
    }

    const length = try vault.findLongestPathLength();
    const expected = @as(usize, 370);
    try testing.expectEqual(expected, length);
}

test "sample part 2 case B" {
    const data =
        \\kglvqrro
    ;

    var vault = Vault.init(testing.allocator, true);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try vault.addLine(line);
    }

    const length = try vault.findLongestPathLength();
    const expected = @as(usize, 492);
    try testing.expectEqual(expected, length);
}

test "sample part 2 case C" {
    const data =
        \\ulqzkmiv
    ;

    var vault = Vault.init(testing.allocator, true);

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try vault.addLine(line);
    }

    const length = try vault.findLongestPathLength();
    const expected = @as(usize, 830);
    try testing.expectEqual(expected, length);
}
