const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Tower = struct {
    const StringId = usize;
    const INFINITY = std.math.maxInt(usize);

    const Program = struct {
        name: StringId,
        weight: usize,
        neighbors: std.ArrayList(StringId),

        pub fn init(allocator: Allocator, name: StringId, weight: usize) Program {
            return .{
                .name = name,
                .weight = weight,
                .neighbors = std.ArrayList(StringId).init(allocator),
            };
        }

        pub fn deinit(self: *Program) void {
            self.neighbors.deinit();
        }
    };

    allocator: Allocator,
    strtab: StringTable,
    programs: std.AutoHashMap(StringId, Program),
    full: std.AutoHashMap(StringId, usize),

    pub fn init(allocator: Allocator) Tower {
        return .{
            .allocator = allocator,
            .strtab = StringTable.init(allocator),
            .programs = std.AutoHashMap(StringId, Program).init(allocator),
            .full = std.AutoHashMap(StringId, usize).init(allocator),
        };
    }

    pub fn deinit(self: *Tower) void {
        self.full.deinit();
        var it = self.programs.valueIterator();
        while (it.next()) |*p| {
            p.*.neighbors.deinit();
        }
        self.programs.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *Tower, line: []const u8) !void {
        var it = std.mem.tokenizeAny(u8, line, " (),");
        const name = it.next().?;
        const weight = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        const id = try self.strtab.add(name);
        var program = Program.init(self.allocator, id, weight);
        var skip: usize = 1;
        while (it.next()) |chunk| {
            if (skip > 0) {
                skip -= 1;
                continue;
            }
            const n = try self.strtab.add(chunk);
            try program.neighbors.append(n);
        }
        try self.programs.put(id, program);
    }

    pub fn show(self: Tower) void {
        std.debug.print("Tower with {} programs:\n", .{self.programs.count()});
        var it = self.programs.valueIterator();
        while (it.next()) |p| {
            std.debug.print("[{s}] ({}):", .{ self.strtab.get_str(p.name) orelse "***", p.weight });
            for (p.neighbors.items) |n| {
                std.debug.print(" [{s}]", .{self.strtab.get_str(n) orelse "***"});
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn findBottomProgram(self: Tower) ![]const u8 {
        var seen = std.AutoHashMap(StringId, void).init(self.allocator);
        defer seen.deinit();
        {
            var it = self.programs.valueIterator();
            while (it.next()) |p| {
                for (p.neighbors.items) |n| {
                    try seen.put(n, {});
                }
            }
        }
        {
            var it = self.programs.valueIterator();
            while (it.next()) |p| {
                if (seen.contains(p.name)) continue;
                return self.strtab.get_str(p.name).?;
            }
        }
        return "";
    }

    pub fn findBalancingWeight(self: *Tower) !usize {
        var seen = std.AutoHashMap(usize, usize).init(self.allocator);
        defer seen.deinit();

        var it = self.programs.valueIterator();
        while (it.next()) |p| {
            if (p.neighbors.items.len == 0) continue;
            seen.clearRetainingCapacity();
            for (p.neighbors.items) |n| {
                const f = try self.getFullWeight(n);
                const r = try seen.getOrPutValue(f, 0);
                r.value_ptr.* += 1;
            }
            var same: usize = INFINITY;
            var diff: usize = INFINITY;
            var its = seen.iterator();
            while (its.next()) |e| {
                if (e.value_ptr.* == 1) {
                    if (diff != INFINITY) return error.InvalidDiff;
                    diff = e.key_ptr.*;
                } else {
                    if (same != INFINITY and same != e.key_ptr.*) return error.InvalidSame;
                    same = e.key_ptr.*;
                }
            }
            if (diff == INFINITY) continue;
            for (p.neighbors.items) |n| {
                const f = try self.getFullWeight(n);
                if (f != diff) continue;
                const q_opt = self.programs.get(n);
                if (q_opt) |q| {
                    var w = q.weight;
                    if (same > diff) {
                        w += same - diff;
                    } else {
                        w -= diff - same;
                    }
                    return w;
                }
            }
        }
        return 0;
    }

    fn getFullWeight(self: *Tower, program: StringId) !usize {
        if (self.full.get(program)) |w| {
            return w;
        }
        var weight: usize = 0;
        const prog = self.programs.get(program);
        if (prog) |p| {
            weight += p.weight;
            for (p.neighbors.items) |n| {
                weight += try self.getFullWeight(n);
            }
        }
        try self.full.put(program, weight);
        return weight;
    }
};

test "sample part 1" {
    const data =
        \\pbga (66)
        \\xhth (57)
        \\ebii (61)
        \\havc (66)
        \\ktlj (57)
        \\fwft (72) -> ktlj, cntj, xhth
        \\qoyq (66)
        \\padx (45) -> pbga, havc, qoyq
        \\tknk (41) -> ugml, padx, fwft
        \\jptl (61)
        \\ugml (68) -> gyxo, ebii, jptl
        \\gyxo (61)
        \\cntj (57)
    ;

    var tower = Tower.init(testing.allocator);
    defer tower.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try tower.addLine(line);
    }
    // tower.show();

    const bottom = try tower.findBottomProgram();
    const expected = "tknk";
    try testing.expectEqualStrings(expected, bottom);
}

test "sample part 2" {
    const data =
        \\pbga (66)
        \\xhth (57)
        \\ebii (61)
        \\havc (66)
        \\ktlj (57)
        \\fwft (72) -> ktlj, cntj, xhth
        \\qoyq (66)
        \\padx (45) -> pbga, havc, qoyq
        \\tknk (41) -> ugml, padx, fwft
        \\jptl (61)
        \\ugml (68) -> gyxo, ebii, jptl
        \\gyxo (61)
        \\cntj (57)
    ;

    var tower = Tower.init(testing.allocator);
    defer tower.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try tower.addLine(line);
    }
    // tower.show();

    const weight = try tower.findBalancingWeight();
    const expected = @as(usize, 60);
    try testing.expectEqual(expected, weight);
}
