const std = @import("std");
const testing = std.testing;
const StringTable = @import("./util/strtab.zig").StringTable;

const Allocator = std.mem.Allocator;

pub const CPU = struct {
    const StringId = usize;
    const NEG_INFINITY = std.math.minInt(isize);

    const Cmp = enum {
        LT,
        LE,
        GT,
        GE,
        EQ,
        NE,

        pub fn parse(str: []const u8) !Cmp {
            if (std.mem.eql(u8, str, "<")) return .LT;
            if (std.mem.eql(u8, str, "<=")) return .LE;
            if (std.mem.eql(u8, str, ">")) return .GT;
            if (std.mem.eql(u8, str, ">=")) return .GE;
            if (std.mem.eql(u8, str, "==")) return .EQ;
            if (std.mem.eql(u8, str, "!=")) return .NE;
            return error.InvalidCmp;
        }

        pub fn eval(self: Cmp, l: isize, r: isize) bool {
            return switch (self) {
                .LT => l < r,
                .LE => l <= r,
                .GT => l > r,
                .GE => l >= r,
                .EQ => l == r,
                .NE => l != r,
            };
        }
    };

    const Op = enum {
        inc,
        dec,

        pub fn parse(str: []const u8) !Op {
            if (std.mem.eql(u8, str, "inc")) return .inc;
            if (std.mem.eql(u8, str, "dec")) return .dec;
            return error.InvalidOp;
        }

        pub fn summand(self: Op, v: isize) isize {
            return switch (self) {
                .inc => v,
                .dec => -v,
            };
        }
    };

    allocator: Allocator,
    strtab: StringTable,
    registers: std.AutoHashMap(StringId, isize),
    highest: isize,

    pub fn init(allocator: Allocator) CPU {
        return .{
            .allocator = allocator,
            .strtab = StringTable.init(allocator),
            .registers = std.AutoHashMap(StringId, isize).init(allocator),
            .highest = NEG_INFINITY,
        };
    }

    pub fn deinit(self: *CPU) void {
        self.registers.deinit();
        self.strtab.deinit();
    }

    pub fn addLine(self: *CPU, line: []const u8) !void {
        var it = std.mem.tokenizeScalar(u8, line, ' ');
        const tgt_name = it.next().?;
        const tgt_id = try self.strtab.add(tgt_name);
        _ = try self.registers.getOrPutValue(tgt_id, 0);
        const op = try Op.parse(it.next().?);
        const delta = try std.fmt.parseInt(isize, it.next().?, 10);
        _ = it.next();
        const src_name = it.next().?;
        const src_id = try self.strtab.add(src_name);
        _ = try self.registers.getOrPutValue(src_id, 0);
        const cmp = try Cmp.parse(it.next().?);
        const value = try std.fmt.parseInt(isize, it.next().?, 10);

        // must do after inserting tgt and src,
        // since insertion might invalidate the entries
        const src = self.registers.getEntry(src_id).?;
        if (!cmp.eval(src.value_ptr.*, value)) return;

        const tgt = self.registers.getEntry(tgt_id).?;
        tgt.value_ptr.* += op.summand(delta);
        if (self.highest < tgt.value_ptr.*) self.highest = tgt.value_ptr.*;
    }

    pub fn getLargestRegister(self: CPU) !isize {
        var largest: isize = NEG_INFINITY;
        var it = self.registers.valueIterator();
        while (it.next()) |r| {
            if (largest < r.*) largest = r.*;
        }
        return largest;
    }

    pub fn getHighestValue(self: CPU) !isize {
        return self.highest;
    }
};

test "sample part 1" {
    const data =
        \\b inc 5 if a > 1
        \\a inc 1 if b < 5
        \\c dec -10 if a >= 1
        \\c inc -20 if c == 10
    ;

    var cpu = CPU.init(testing.allocator);
    defer cpu.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cpu.addLine(line);
    }

    const largest = try cpu.getLargestRegister();
    const expected = @as(isize, 1);
    try testing.expectEqual(expected, largest);
}

test "sample part 2" {
    const data =
        \\b inc 5 if a > 1
        \\a inc 1 if b < 5
        \\c dec -10 if a >= 1
        \\c inc -20 if c == 10
    ;

    var cpu = CPU.init(testing.allocator);
    defer cpu.deinit();

    var it = std.mem.split(u8, data, "\n");
    while (it.next()) |line| {
        try cpu.addLine(line);
    }

    const largest = try cpu.getHighestValue();
    const expected = @as(isize, 10);
    try testing.expectEqual(expected, largest);
}
