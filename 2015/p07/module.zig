const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const Board = struct {
    const StringId = StringTable.StringId;
    const INVALID_STRING = std.math.maxInt(StringId);

    const Op = enum {
        Set,
        Not,
        And,
        Or,
        RShift,
        LShift,

        pub fn parse(text: []const u8) !Op {
            if (std.mem.eql(u8, text, "NOT")) return .Not;
            if (std.mem.eql(u8, text, "AND")) return .And;
            if (std.mem.eql(u8, text, "OR")) return .Or;
            if (std.mem.eql(u8, text, "LSHIFT")) return .LShift;
            if (std.mem.eql(u8, text, "RSHIFT")) return .RShift;
            return error.InvalidOp;
        }
    };

    const Node = struct {
        name: StringId,
        op: Op,
        l: StringId,
        r: StringId,

        pub fn init1(name: StringId, op: Op, v: StringId) Node {
            return Node.init2(name, op, v, INVALID_STRING);
        }

        pub fn init2(name: StringId, op: Op, l: StringId, r: StringId) Node {
            return Node{ .name = name, .op = op, .l = l, .r = r };
        }

        pub fn eval(self: Node, l: u16, r: u16) u16 {
            return switch (self.op) {
                .Set => l,
                .Not => ~l,
                .And => l & r,
                .Or => l | r,
                .LShift => l << @intCast(r),
                .RShift => l >> @intCast(r),
            };
        }
    };

    allocator: Allocator,
    strtab: StringTable,
    nodes: std.AutoHashMap(StringId, Node),
    cache: std.AutoHashMap(StringId, u16),

    pub fn init(allocator: Allocator) Board {
        const self = Board{
            .allocator = allocator,
            .strtab = StringTable.init(allocator),
            .nodes = std.AutoHashMap(StringId, Node).init(allocator),
            .cache = std.AutoHashMap(StringId, u16).init(allocator),
        };
        return self;
    }

    pub fn deinit(self: *Board) void {
        self.cache.deinit();
        self.nodes.deinit();
        self.strtab.deinit();
    }

    pub fn clear(self: *Board) void {
        self.cache.clearRetainingCapacity();
    }

    pub fn addLine(self: *Board, line: []const u8) !void {
        var parts = std.ArrayList([]const u8).init(self.allocator);
        defer parts.deinit();
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        while (it.next()) |part| {
            try parts.append(part);
        }

        const node: Node = switch (parts.items.len) {
            3 => blk: {
                const name = try self.strtab.add(parts.items[2]);
                const value = try self.strtab.add(parts.items[0]);
                const op = Op.Set;
                break :blk Node.init1(name, op, value);
            },
            4 => blk: {
                const name = try self.strtab.add(parts.items[3]);
                const value = try self.strtab.add(parts.items[1]);
                const op = try Op.parse(parts.items[0]);
                break :blk Node.init1(name, op, value);
            },
            5 => blk: {
                const name = try self.strtab.add(parts.items[4]);
                const l = try self.strtab.add(parts.items[0]);
                const r = try self.strtab.add(parts.items[2]);
                const op = try Op.parse(parts.items[1]);
                break :blk Node.init2(name, op, l, r);
            },
            else => {
                return error.InvalidData;
            },
        };
        try self.nodes.put(node.name, node);
    }

    pub fn show(self: Board) void {
        std.debug.print("Board with {} nodes\n", .{self.nodes.count()});
        var it = self.nodes.valueIterator();
        while (it.next()) |node| {
            std.debug.print("  {s} => {} {s} {s}\n", .{
                self.strtab.get_str(node.name) orelse "***",
                node.op,
                self.strtab.get_str(node.l) orelse "***",
                self.strtab.get_str(node.r) orelse "***",
            });
        }
    }

    pub fn getWireSignal(self: *Board, wire: []const u8) !u16 {
        const id_maybe = self.strtab.get_pos(wire);
        if (id_maybe) |id| {
            return self.findNode(id);
        }
        return error.InvalidWire;
    }

    pub fn cloneAndGetWireSignal(self: *Board, first: []const u8, second: []const u8) !u16 {
        const signal_before = try self.getWireSignal(first);
        self.clear();
        try self.setWireSignal(second, signal_before);
        const signal_after = try self.getWireSignal(first);
        return signal_after;
    }

    fn setWireSignal(self: *Board, wire: []const u8, value: u16) !void {
        const id_maybe = self.strtab.get_pos(wire);
        if (id_maybe) |id| {
            try self.cache.put(id, value);
        } else {
            return error.InvalidWire;
        }
    }

    fn findNode(self: *Board, wire: StringId) !u16 {
        const cached_maybe = self.cache.get(wire);
        if (cached_maybe) |cached| return cached;

        const name_maybe = self.strtab.get_str(wire);
        if (name_maybe) |name| {
            const value = std.fmt.parseUnsigned(u16, name, 10) catch blk: {
                const node_maybe = self.nodes.get(wire);
                if (node_maybe) |node| {
                    const l = try self.findNode(node.l);
                    const r = if (node.r != INVALID_STRING) try self.findNode(node.r) else 0;
                    break :blk node.eval(l, r);
                } else {
                    return error.InvalidWire;
                }
            };
            try self.cache.put(wire, value);
            return value;
        }

        return error.InvalidWire;
    }
};

test "sample part 1" {
    const data =
        \\123 -> x
        \\456 -> y
        \\x AND y -> d
        \\x OR y -> e
        \\x LSHIFT 2 -> f
        \\y RSHIFT 2 -> g
        \\NOT x -> h
        \\NOT y -> i
    ;

    var board = Board.init(std.testing.allocator);
    defer board.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try board.addLine(line);
    }
    // board.show();

    {
        const signal = try board.getWireSignal("d");
        const expected = @as(usize, 72);
        try testing.expectEqual(expected, signal);
    }
    {
        const signal = try board.getWireSignal("e");
        const expected = @as(usize, 507);
        try testing.expectEqual(expected, signal);
    }
    {
        const signal = try board.getWireSignal("f");
        const expected = @as(usize, 492);
        try testing.expectEqual(expected, signal);
    }
    {
        const signal = try board.getWireSignal("g");
        const expected = @as(usize, 114);
        try testing.expectEqual(expected, signal);
    }
    {
        const signal = try board.getWireSignal("h");
        const expected = @as(usize, 65412);
        try testing.expectEqual(expected, signal);
    }
    {
        const signal = try board.getWireSignal("i");
        const expected = @as(usize, 65079);
        try testing.expectEqual(expected, signal);
    }
    {
        const signal = try board.getWireSignal("x");
        const expected = @as(usize, 123);
        try testing.expectEqual(expected, signal);
    }
    {
        const signal = try board.getWireSignal("y");
        const expected = @as(usize, 456);
        try testing.expectEqual(expected, signal);
    }
}
