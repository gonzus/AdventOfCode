const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Module = struct {
    const Cpu = struct {
        code: usize,

        pub fn init(name: []const u8) Cpu {
            var code: usize = 0;
            code *= 100;
            code += name[0] - 'a' + 1;
            code *= 100;
            code += name[1] - 'a' + 1;
            return .{
                .code = code,
            };
        }

        pub fn equals(self: Cpu, other: Cpu) bool {
            return self.code == other.code;
        }

        pub fn startsWith(self: Cpu, c: u8) bool {
            const s: u8 = @intCast((self.code / 100) % 100 + 'a' - 1);
            return s == c;
        }

        pub fn format(
            computer: Cpu,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            var name: [2]u8 = undefined;
            var code = computer.code;
            name[1] = @intCast(code % 100);
            name[1] += 'a' - 1;
            code /= 100;
            name[0] = @intCast(code % 100);
            name[0] += 'a' - 1;
            code /= 100;
            _ = try writer.print("{s}", .{&name});
        }
    };

    const Pair = struct {
        code: usize,

        pub fn init(l: Cpu, r: Cpu) Pair {
            var cl = l;
            var cr = r;
            if (r.code < l.code) {
                const t = cl;
                cl = cr;
                cr = t;
            }
            return .{
                .code = cl.code * 10000 + cr.code,
            };
        }

        pub fn car(self: Pair) Cpu {
            return Cpu{ .code = (self.code / 10000) % 10000 };
        }

        pub fn cdr(self: Pair) Cpu {
            return Cpu{ .code = self.code % 10000 };
        }

        pub fn contains(self: Pair, cpu: Cpu) bool {
            if (cpu.equals(self.car())) return true;
            if (cpu.equals(self.cdr())) return true;
            return false;
        }

        pub fn format(
            pair: Pair,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = try writer.print("{}-{}", .{ pair.car(), pair.cdr() });
        }
    };

    const Group = struct {
        const SIZE = 1000;

        fbuf: [SIZE]usize,
        flen: usize,

        pub fn init() Group {
            return .{
                .fbuf = [_]usize{0} ** SIZE,
                .flen = 0,
            };
        }

        pub fn size(self: Group) usize {
            return self.flen;
        }

        pub fn get(self: Group, pos: usize) !Cpu {
            if (pos >= self.flen) return error.InvalidGroupPos;
            return Cpu{ .code = self.fbuf[pos] };
        }

        pub fn sort(self: *Group) !void {
            std.sort.heap(usize, self.fbuf[0..self.flen], {}, std.sort.asc(usize));
        }

        pub fn add(self: *Group, cpu: Cpu) void {
            for (0..self.flen) |p| {
                if (self.fbuf[p] == cpu.code) return;
            }
            self.fbuf[self.flen] = cpu.code;
            self.flen += 1;
        }

        pub fn remove(self: *Group, cpu: Cpu) void {
            var len = self.flen;
            for (0..len) |p| {
                if (self.fbuf[p] != cpu.code) continue;
                len -= 1;
                self.fbuf[p] = self.fbuf[len];
                self.fbuf[len] = 0;
                break;
            }
            self.flen = len;
        }

        pub fn lessThan(_: void, l: Group, r: Group) std.math.Order {
            return std.math.order(l.size(), r.size()).invert();
        }

        pub fn format(
            group: Group,
            comptime _: []const u8,
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            for (0..group.flen) |p| {
                if (p > 0) {
                    _ = try writer.print(",", .{});
                }
                const cpu = Cpu{ .code = group.fbuf[p] };
                _ = try writer.print("{}", .{cpu});
            }
        }
    };

    const CpuSet = std.AutoHashMap(Cpu, void);
    const PairSet = std.AutoHashMap(Pair, void);
    const GroupSet = std.AutoHashMap(Group, void);
    const CpuMap = std.AutoHashMap(Cpu, CpuSet);
    const PQ = std.PriorityQueue(Group, void, Group.lessThan);

    allocator: Allocator,
    pairs: PairSet,
    cpus: CpuSet,
    groups: GroupSet,
    password: [1024]u8,

    pub fn init(allocator: Allocator) Module {
        return .{
            .allocator = allocator,
            .pairs = PairSet.init(allocator),
            .cpus = CpuSet.init(allocator),
            .groups = GroupSet.init(allocator),
            .password = undefined,
        };
    }

    pub fn deinit(self: *Module) void {
        self.groups.deinit();
        self.cpus.deinit();
        self.pairs.deinit();
    }

    pub fn addLine(self: *Module, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, '-');
        const l = Cpu.init(it.next().?);
        const r = Cpu.init(it.next().?);
        _ = try self.cpus.getOrPut(l);
        _ = try self.cpus.getOrPut(r);
        _ = try self.pairs.getOrPut(Pair.init(l, r));
    }

    // pub fn show(self: Module) void {
    //     std.debug.print("Graph\n", .{});
    //     {
    //         std.debug.print("CPUs: {}\n", .{self.cpus.count()});
    //         var it = self.cpus.keyIterator();
    //         while (it.next()) |c| {
    //             std.debug.print(" {}\n", .{c.*});
    //         }
    //     }
    //     {
    //         std.debug.print("Pairs (SORTED): {}\n", .{self.pairs.count()});
    //         var it = self.pairs.keyIterator();
    //         while (it.next()) |p| {
    //             std.debug.print(" {}\n", .{p.*});
    //         }
    //     }
    //     {
    //         std.debug.print("Groups: {}\n", .{self.groups.count()});
    //         var it = self.groups.keyIterator();
    //         while (it.next()) |g| {
    //             std.debug.print(" {}\n", .{g.*});
    //         }
    //     }
    // }

    pub fn findSetsOfThreeStartingWith(self: *Module, start: u8) !usize {
        // self.show();

        // we could to this with a GroupSet, but searching for common elements
        // in two adjavency sets becomes too expensive: O(n) instead of O(1)
        var groups = CpuMap.init(self.allocator);
        defer {
            var it = groups.valueIterator();
            while (it.next()) |s| {
                s.*.deinit();
            }
            groups.deinit();
        }

        // create a map with all directly-connectd cpus
        // each element is a set of the connected cpus
        var itc = self.cpus.keyIterator();
        while (itc.next()) |c| {
            const cpu = c.*;
            var set = CpuSet.init(self.allocator);
            var itp = self.pairs.keyIterator();
            while (itp.next()) |p| {
                const pair = p.*;
                if (cpu.equals(pair.car())) {
                    _ = try set.getOrPut(pair.cdr());
                }
                if (cpu.equals(pair.cdr())) {
                    _ = try set.getOrPut(pair.car());
                }
            }
            try groups.put(cpu, set);
        }

        var count: usize = 0;
        self.groups.clearRetainingCapacity();
        var it0 = groups.iterator();
        while (it0.next()) |e0| {
            const cpu0 = e0.key_ptr.*;
            const set0 = e0.value_ptr.*;
            var it1 = groups.iterator();
            while (it1.next()) |e1| {
                const cpu1 = e1.key_ptr.*;
                if (cpu0.code >= cpu1.code) continue;
                if (!set0.contains(cpu1)) continue;
                const set1 = e1.value_ptr.*;
                if (!set1.contains(cpu0)) continue;

                // cpu0 and cpu1 are adjacent
                // search for common elements in their adjacency sets
                var it2 = set1.keyIterator();
                while (it2.next()) |e2| {
                    const cpu2 = e2.*;
                    if (cpu2.equals(cpu0)) continue;
                    if (cpu2.equals(cpu1)) continue;
                    if (!set0.contains(cpu2)) continue;
                    if (!set1.contains(cpu2)) continue;

                    // found one common element => triple found
                    var triple = Group.init();
                    triple.add(cpu0);
                    triple.add(cpu1);
                    triple.add(cpu2);

                    // check if one of the cpus starts with our letter
                    var include = false;
                    for (0..triple.size()) |p| {
                        const cpu = try triple.get(p);
                        if (cpu.startsWith(start)) {
                            include = true;
                            break;
                        }
                    }
                    if (!include) continue;

                    // sort cpus to avoid duplicates
                    try triple.sort();
                    const r = try self.groups.getOrPut(triple);
                    if (r.found_existing) continue;

                    count += 1;
                }
            }
        }
        return count;
    }

    pub fn getLanPartyPassword(self: *Module) ![]const u8 {
        var pending = PQ.init(self.allocator, {});
        defer pending.deinit();

        self.groups.clearRetainingCapacity();
        var it = self.cpus.keyIterator();
        while (it.next()) |c| {
            const cpu = c.*;
            var group = Group.init();
            var itp = self.pairs.keyIterator();
            while (itp.next()) |p| {
                const pair = p.*;
                if (!pair.contains(cpu)) continue;
                group.add(pair.car());
                group.add(pair.cdr());
            }
            _ = try self.groups.getOrPut(group);
            try pending.add(group);
        }
        // self.show();

        while (pending.count() != 0) {
            const group = pending.remove();
            var all = true;
            ALL: for (0..group.size()) |p0| {
                const cpu0 = try group.get(p0);
                for (0..group.size()) |p1| {
                    const cpu1 = try group.get(p1);
                    if (cpu0.code >= cpu1.code) continue;
                    const pair = Pair.init(cpu0, cpu1);
                    if (!self.pairs.contains(pair)) {
                        all = false;
                        break :ALL;
                    }
                }
            }
            if (all) {
                var friends = group;
                try friends.sort();
                const txt = std.fmt.bufPrint(&self.password, "{}", .{friends});
                return txt;
            }
            for (0..group.size()) |p| {
                const cpu = try group.get(p);
                var friends = group;
                friends.remove(cpu);
                try pending.add(friends);
            }
        }

        return "";
    }
};

test "sample part 1" {
    const data =
        \\kh-tc
        \\qp-kh
        \\de-cg
        \\ka-co
        \\yn-aq
        \\qp-ub
        \\cg-tb
        \\vc-aq
        \\tb-ka
        \\wh-tc
        \\yn-cg
        \\kh-ub
        \\ta-co
        \\de-co
        \\tc-td
        \\tb-wq
        \\wh-td
        \\ta-ka
        \\td-qp
        \\aq-cg
        \\wq-ub
        \\ub-vc
        \\de-ta
        \\wq-aq
        \\wq-vc
        \\wh-yn
        \\ka-de
        \\kh-ta
        \\co-tc
        \\wh-qp
        \\tb-vc
        \\td-yn
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const count = try module.findSetsOfThreeStartingWith('t');
    const expected = @as(usize, 7);
    try testing.expectEqual(expected, count);
}

test "sample part 2" {
    const data =
        \\kh-tc
        \\qp-kh
        \\de-cg
        \\ka-co
        \\yn-aq
        \\qp-ub
        \\cg-tb
        \\vc-aq
        \\tb-ka
        \\wh-tc
        \\yn-cg
        \\kh-ub
        \\ta-co
        \\de-co
        \\tc-td
        \\tb-wq
        \\wh-td
        \\ta-ka
        \\td-qp
        \\aq-cg
        \\wq-ub
        \\ub-vc
        \\de-ta
        \\wq-aq
        \\wq-vc
        \\wh-yn
        \\ka-de
        \\kh-ta
        \\co-tc
        \\wh-qp
        \\tb-vc
        \\td-yn
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try module.addLine(line);
    }

    const password = try module.getLanPartyPassword();
    const expected = "co,de,ka,ta";
    try testing.expectEqualStrings(expected, password);
}
