const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

pub const Module = struct {
    const StringId = StringTable.StringId;
    const INVALID = std.math.maxInt(StringId);

    const Edge = struct {
        src: StringId,
        tgt: StringId,

        pub fn init(src: StringId, tgt: StringId) Edge {
            return .{ .src = src, .tgt = tgt };
        }
    };

    const Node = struct {
        id: StringId,
        neighbors: std.AutoHashMap(usize, void),

        pub fn init(alloc: std.mem.Allocator, id: StringId) Node {
            return .{ .id = id, .neighbors = .init(alloc) };
        }

        pub fn deinit(self: *Node) void {
            self.neighbors.deinit();
        }

        pub fn addNeighbor(self: *Node, id: StringId) !void {
            _ = try self.neighbors.getOrPut(id);
        }
    };

    alloc: std.mem.Allocator,
    strtab: StringTable,
    nodes: std.AutoHashMap(usize, Node),
    cache: std.AutoHashMap(Edge, usize),

    pub fn init(alloc: std.mem.Allocator) Module {
        return .{
            .alloc = alloc,
            .strtab = StringTable.init(alloc),
            .nodes = std.AutoHashMap(usize, Node).init(alloc),
            .cache = std.AutoHashMap(Edge, usize).init(alloc),
        };
    }

    pub fn deinit(self: *Module) void {
        var it = self.nodes.valueIterator();
        while (it.next()) |n| {
            n.deinit();
        }
        self.cache.deinit();
        self.nodes.deinit();
        self.strtab.deinit();
    }

    pub fn parseInput(self: *Module, data: []const u8) !void {
        var it_lines = std.mem.splitScalar(u8, data, '\n');
        while (it_lines.next()) |line| {
            var nid: StringId = INVALID;
            var node: ?Node = null;
            var it = std.mem.tokenizeAny(u8, line, ": ");
            while (it.next()) |chunk| {
                const sid = try self.strtab.add(chunk);
                if (nid == INVALID) {
                    nid = sid;
                    node = Node.init(self.alloc, nid);
                    continue;
                }
                try node.?.addNeighbor(sid);
            }
            try self.nodes.put(nid, node.?);
        }
    }

    pub fn countDirectPaths(self: *Module) !usize {
        self.cache.clearRetainingCapacity();

        const you = self.strtab.get_pos("you").?;
        const out = self.strtab.get_pos("out").?;
        return try self.countPaths(you, out);
    }

    pub fn countPathsWithWaypoints(self: *Module) !usize {
        self.cache.clearRetainingCapacity();

        const svr = self.strtab.get_pos("svr").?;
        const dac = self.strtab.get_pos("dac").?;
        const fft = self.strtab.get_pos("fft").?;
        const out = self.strtab.get_pos("out").?;
        var paths: usize = 0;
        {
            // svr -> dac -> fft -> out
            var variant: usize = 1;
            variant *= try self.countPaths(svr, dac);
            variant *= try self.countPaths(dac, fft);
            variant *= try self.countPaths(fft, out);
            paths += variant;
        }
        {
            // svr -> fft -> dac -> out
            var variant: usize = 1;
            variant *= try self.countPaths(svr, fft);
            variant *= try self.countPaths(fft, dac);
            variant *= try self.countPaths(dac, out);
            paths += variant;
        }
        return paths;
    }

    fn countPaths(self: *Module, src: StringId, tgt: StringId) !usize {
        if (src == tgt) return 1;

        const key = Edge.init(src, tgt);
        if (self.cache.get(key)) |v| return v;

        var count: usize = 0;
        if (self.nodes.get(src)) |u| {
            var it = u.neighbors.keyIterator();
            while (it.next()) |v| {
                count += try self.countPaths(v.*, tgt);
            }
        }
        try self.cache.put(key, count);
        return count;
    }
};

test "sample part 1" {
    const data =
        \\aaa: you hhh
        \\you: bbb ccc
        \\bbb: ddd eee
        \\ccc: ddd eee fff
        \\ddd: ggg
        \\eee: out
        \\fff: out
        \\ggg: out
        \\hhh: ccc fff iii
        \\iii: out
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();
    try module.parseInput(data);

    const product = try module.countDirectPaths();
    const expected = @as(usize, 5);
    try testing.expectEqual(expected, product);
}

test "sample part 2" {
    const data =
        \\svr: aaa bbb
        \\aaa: fft
        \\fft: ccc
        \\bbb: tty
        \\tty: ccc
        \\ccc: ddd eee
        \\ddd: hub
        \\hub: fff
        \\eee: dac
        \\dac: fff
        \\fff: ggg hhh
        \\ggg: out
        \\hhh: out
    ;

    var module = Module.init(testing.allocator);
    defer module.deinit();
    try module.parseInput(data);

    const product = try module.countPathsWithWaypoints();
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, product);
}
