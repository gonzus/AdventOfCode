const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Village = struct {
    const Program = struct {
        id: usize,
        neighbors: std.ArrayList(usize),

        pub fn init(allocator: Allocator, id: usize) Program {
            return .{
                .id = id,
                .neighbors = std.ArrayList(usize).init(allocator),
            };
        }

        pub fn deinit(self: *Program) void {
            self.neighbors.deinit();
        }

        pub fn addNeighbor(self: *Program, id: usize) !void {
            try self.neighbors.append(id);
        }
    };

    allocator: Allocator,
    programs: std.AutoHashMap(usize, Program),

    pub fn init(allocator: Allocator) Village {
        return .{
            .allocator = allocator,
            .programs = std.AutoHashMap(usize, Program).init(allocator),
        };
    }

    pub fn deinit(self: *Village) void {
        var it = self.programs.valueIterator();
        while (it.next()) |p| {
            p.*.deinit();
        }
        self.programs.deinit();
    }

    pub fn addLine(self: *Village, line: []const u8) !void {
        var it = std.mem.tokenizeAny(u8, line, " <->,");
        const id = try std.fmt.parseUnsigned(usize, it.next().?, 10);
        var program = Program.init(self.allocator, id);
        while (it.next()) |chunk| {
            const n = try std.fmt.parseUnsigned(usize, chunk, 10);
            try program.addNeighbor(n);
        }
        try self.programs.put(program.id, program);
    }

    const Seen = std.AutoHashMap(usize, void);

    pub fn getGroupSize(self: Village, member: usize) !usize {
        var seen = Seen.init(self.allocator);
        defer seen.deinit();
        try self.floodNeighbors(member, &seen);
        return seen.count();
    }

    pub fn getGroupCount(self: Village) !usize {
        var seen = Seen.init(self.allocator);
        defer seen.deinit();
        var count: usize = 0;
        while (seen.count() < self.programs.count()) {
            var it = self.programs.valueIterator();
            while (it.next()) |p| {
                if (seen.contains(p.id)) continue;
                count += 1;
                try self.floodNeighbors(p.id, &seen);
            }
        }
        return count;
    }

    fn floodNeighbors(self: Village, id: usize, seen: *Seen) !void {
        try seen.put(id, {});
        const program = self.programs.get(id);
        if (program) |p| {
            for (p.neighbors.items) |n| {
                if (seen.contains(n)) continue;
                try self.floodNeighbors(n, seen);
            }
        }
    }
};

test "sample part 1" {
    const data =
        \\0 <-> 2
        \\1 <-> 1
        \\2 <-> 0, 3, 4
        \\3 <-> 2, 4
        \\4 <-> 2, 3, 6
        \\5 <-> 6
        \\6 <-> 4, 5
    ;

    var village = Village.init(testing.allocator);
    defer village.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try village.addLine(line);
    }

    const size = try village.getGroupSize(0);
    const expected = @as(usize, 6);
    try testing.expectEqual(expected, size);
}

test "sample part 2" {
    const data =
        \\0 <-> 2
        \\1 <-> 1
        \\2 <-> 0, 3, 4
        \\3 <-> 2, 4
        \\4 <-> 2, 3, 6
        \\5 <-> 6
        \\6 <-> 4, 5
    ;

    var village = Village.init(testing.allocator);
    defer village.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try village.addLine(line);
    }

    const count = try village.getGroupCount();
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, count);
}
