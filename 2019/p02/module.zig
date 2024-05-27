const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;

pub const Computer = struct {
    const Op = enum(u8) {
        add = 1,
        mul = 2,
        stop = 99,

        pub fn decode(num: usize) !Op {
            for (Ops) |op| {
                if (@intFromEnum(op) == num) return op;
            }
            return error.InvalidOp;
        }
    };
    const Ops = std.meta.tags(Op);

    code: std.ArrayList(usize),
    data: std.ArrayList(usize),
    pc: usize,

    pub fn init(allocator: Allocator) Computer {
        return .{
            .code = std.ArrayList(usize).init(allocator),
            .data = std.ArrayList(usize).init(allocator),
            .pc = 0,
        };
    }

    pub fn deinit(self: *Computer) void {
        self.data.deinit();
        self.code.deinit();
    }

    pub fn addLine(self: *Computer, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ',');
        while (it.next()) |chunk| {
            try self.code.append(try std.fmt.parseUnsigned(usize, chunk, 10));
        }
    }

    pub fn restoreGravityAssist(self: *Computer) !usize {
        try self.reset();
        self.data.items[1] = 12;
        self.data.items[2] = 2;
        try self.run();
        return self.data.items[0];
    }

    pub fn findNounVerb(self: *Computer, wanted: usize) !usize {
        for (0..100) |noun| {
            for (0..100) |verb| {
                try self.reset();
                self.data.items[1] = noun;
                self.data.items[2] = verb;
                try self.run();
                const value = self.data.items[0];
                if (value != wanted) continue;
                return noun * 100 + verb;
            }
        }
        return 0;
    }

    fn reset(self: *Computer) !void {
        self.data.clearRetainingCapacity();
        for (self.code.items) |c| {
            try self.data.append(c);
        }
        self.pc = 0;
    }

    fn runAndReturn(self: *Computer, pos: usize) !usize {
        try self.reset();
        try self.run();
        return self.data.items[pos];
    }

    fn run(self: *Computer) !void {
        var data = self.data.items;
        while (true) : (self.pc += 4) {
            const op = try Op.decode(data[self.pc + 0]);
            if (op == .stop) break;
            const p1 = data[self.pc + 1];
            const p2 = data[self.pc + 2];
            const p3 = data[self.pc + 3];
            switch (op) {
                .add => data[p3] = data[p1] + data[p2],
                .mul => data[p3] = data[p1] * data[p2],
                else => return error.InvalidOp,
            }
        }
    }
};

test "simple - pos 0 becomes 3500" {
    const data =
        \\1,9,10,3,2,3,11,0,99,30,40,50
    ;

    var computer = Computer.init(testing.allocator);
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.addLine(line);
    }

    const value = try computer.runAndReturn(0);
    const expected = @as(usize, 3500);
    try testing.expectEqual(expected, value);
}

test "simple - pos 0 becomes 2" {
    const data =
        \\1,0,0,0,99
    ;

    var computer = Computer.init(testing.allocator);
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.addLine(line);
    }

    const value = try computer.runAndReturn(0);
    const expected = @as(usize, 2);
    try testing.expectEqual(expected, value);
}

test "simple - pos 3 becomes 6" {
    const data =
        \\2,3,0,3,99
    ;

    var computer = Computer.init(testing.allocator);
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.addLine(line);
    }

    const value = try computer.runAndReturn(3);
    const expected = @as(usize, 6);
    try testing.expectEqual(expected, value);
}

test "simple - pos 5 becomes 9801" {
    const data =
        \\2,4,4,5,99,0
    ;

    var computer = Computer.init(testing.allocator);
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.addLine(line);
    }

    const value = try computer.runAndReturn(5);
    const expected = @as(usize, 9801);
    try testing.expectEqual(expected, value);
}

test "simple - pos 0 becomes 30" {
    const data =
        \\1,1,1,4,99,5,6,0,99
    ;

    var computer = Computer.init(testing.allocator);
    defer computer.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try computer.addLine(line);
    }

    const value = try computer.runAndReturn(0);
    const expected = @as(usize, 30);
    try testing.expectEqual(expected, value);
}
